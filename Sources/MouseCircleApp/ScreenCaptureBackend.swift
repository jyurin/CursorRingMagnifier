import AppKit
import CoreMedia
import ScreenCaptureKit

@MainActor
final class ScreenCaptureBackend: CaptureBackend {
    var onFrame: ((UUID, CMSampleBuffer) -> Void)?
    var onFailure: ((UUID, String) -> Void)?
    private let queue = DispatchQueue(label: "com.example.cursorringmagnifier.frames", qos: .userInteractive)
    private var stream: SCStream?
    private var output: CaptureOutput?
    private var cachedContent: SCShareableContent?
    private var cachedRevision = -1
    private var contentTime: TimeInterval = 0

    func start(_ request: CaptureRequest, session: UUID) async throws {
        let now = ProcessInfo.processInfo.systemUptime
        if cachedContent == nil || cachedRevision != request.contentRevision || now - contentTime > 10 ||
            cachedContent?.displays.contains(where: { $0.displayID == request.displayID }) != true {
            cachedContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            cachedRevision = request.contentRevision
            contentTime = now
        }
        guard let content = cachedContent,
              let display = content.displays.first(where: { $0.displayID == request.displayID }),
              let ownApp = content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier }) else {
            cachedContent = nil
            throw CaptureError.sourceUnavailable
        }

        // Exclude our process, including overlay windows created after enumeration. Keep settings magnifiable.
        // This filter affects ONLY our stream; Zoom can still capture both overlays normally.
        let settingsWindows = content.windows.filter {
            $0.owningApplication?.processID == ownApp.processID && !request.excludedWindowIDs.contains($0.windowID)
        }
        let filter = SCContentFilter(display: display, excludingApplications: [ownApp], exceptingWindows: settingsWindows)
        let output = CaptureOutput(onFrame: { [weak self] buffer in
            self?.onFrame?(session, buffer)
        }, onFailure: { [weak self] message in
            self?.onFailure?(session, message)
        })
        let stream = SCStream(filter: filter, configuration: Self.configuration(request), delegate: output)
        self.stream = stream
        self.output = output
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
    }

    func update(_ request: CaptureRequest) async throws {
        try await stream?.updateConfiguration(Self.configuration(request))
    }

    func discardFrames() { output?.invalidate() }

    func stop() async {
        output?.invalidate()
        if let stream {
            try? await stream.stopCapture()
            if let output { try? stream.removeStreamOutput(output, type: .screen) }
        }
        stream = nil
        output = nil
    }

    static func configuration(_ request: CaptureRequest) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.sourceRect = request.sourceRect
        config.width = request.pixelWidth
        config.height = request.pixelHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.showsCursor = false
        config.capturesAudio = false
        return config
    }
}

private enum CaptureError: LocalizedError {
    case sourceUnavailable
    var errorDescription: String? { "画面の情報を取得できませんでした。拡大鏡のキーを離し、もう一度押してください。" }
}

// ScreenCaptureKit calls on a serial background queue. The lock protects the one-slot mailbox;
// only the main actor consumes its buffer. Slow UI never builds a backlog of screen images.
private final class CaptureOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: CMSampleBuffer?
    private var scheduled = false
    private var accepting = true
    private let onFrame: @MainActor @Sendable (CMSampleBuffer) -> Void
    private let onFailure: @MainActor @Sendable (String) -> Void

    init(onFrame: @escaping @MainActor @Sendable (CMSampleBuffer) -> Void,
         onFailure: @escaping @MainActor @Sendable (String) -> Void) {
        self.onFrame = onFrame
        self.onFailure = onFailure
    }

    func invalidate() {
        lock.lock()
        accepting = false
        pending = nil
        lock.unlock()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid, CMSampleBufferGetImageBuffer(buffer) != nil,
              let info = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = info.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue else { return }
        lock.lock()
        guard accepting else { lock.unlock(); return }
        pending = buffer
        let shouldSchedule = !scheduled
        scheduled = true
        lock.unlock()
        if shouldSchedule {
            DispatchQueue.main.async { [weak self] in self?.deliverLatest() }
        }
    }

    @MainActor
    private func deliverLatest() {
        lock.lock()
        let buffer = pending
        pending = nil
        scheduled = false
        lock.unlock()
        if let buffer { onFrame(buffer) }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        invalidate()
        DispatchQueue.main.async { [weak self] in self?.onFailure(message) }
    }
}
