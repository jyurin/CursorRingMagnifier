import AppKit

@MainActor
final class OverlayWindowManager {
    var onCaptureFailure: ((String) -> Void)?
    private let ringView = RingOverlayView(frame: .zero)
    private let lensView = MagnifierView(frame: .zero)
    private let ringWindow: NSPanel
    private let lensWindow: NSPanel
    private let backend = ScreenCaptureBackend()
    private let capture: CaptureCoordinator
    private let captureUpdates = FrameCoalescer<CaptureRequest>(framesPerSecond: 30)
    private var settings = AppSettings()
    private var clicks = ClickState()
    private var cursor = NSEvent.mouseLocation
    private var screens: [NSScreen] = []
    private var magnifierActive = false
    private var suppressed = false
    private var suspended = false
    private var lensHasFrame = false
    private var lensDisplay: CGDirectDisplayID?
    private var contentRevision = 0
    private(set) var windowMoveCount = 0

    init() {
        ringWindow = Self.makeWindow(title: "Cursor Ring Overlay", shadow: false)
        lensWindow = Self.makeWindow(title: "Cursor Magnifier Overlay", shadow: true)
        capture = CaptureCoordinator(backend: backend)
        ringWindow.contentView = ringView
        lensWindow.contentView = lensView
        captureUpdates.deliver = { [weak self] request in
            guard let self, self.canMagnify else { return }
            self.capture.setRequest(request)
        }
        backend.onFrame = { [weak self] session, buffer in
            guard let self, self.canMagnify, self.capture.accepts(session) else { return }
            if self.lensView.display(buffer), !self.lensHasFrame {
                self.lensHasFrame = true
                self.lensWindow.orderFrontRegardless()
            }
        }
        backend.onFailure = { [weak self] session, message in
            self?.capture.failed(session: session, message: message)
        }
        capture.onFailure = { [weak self] message in
            self?.setMagnifierActive(false)
            self?.onCaptureFailure?(message)
        }
        screens = NSScreen.screens
    }

    func apply(_ settings: AppSettings) {
        let changed = self.settings != settings
        self.settings = settings
        if !settings.highlightEnabled {
            clicks = ClickState()
            setMagnifierActive(false)
        }
        if changed { updateAppearance() }
        refresh()
    }

    func moveCursor(to point: CGPoint) {
        guard point != cursor else { return }
        cursor = point
        refresh()
    }

    func setClick(pressed: Bool, secondary: Bool) {
        clicks.set(pressed: pressed, secondary: secondary)
        if settings.highlightEnabled { ringView.update(settings: settings, clicks: clicks) }
    }

    func resetClicks() {
        clicks = ClickState()
        ringView.update(settings: settings, clicks: clicks)
    }

    func setMagnifierActive(_ active: Bool) {
        let active = active && settings.highlightEnabled && !suppressed && !suspended
        guard active != magnifierActive else { return }
        magnifierActive = active
        if !active { stopCapture() }
        else { updateAppearance() }
        refresh()
    }

    func setSuppressed(_ value: Bool) {
        guard value != suppressed else { return }
        suppressed = value
        if value { setMagnifierActive(false) }
        refresh()
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        if value {
            setMagnifierActive(false)
            resetClicks()
        } else {
            cursor = NSEvent.mouseLocation
            screensChanged()
        }
        refresh()
    }

    func screensChanged() {
        screens = NSScreen.screens
        captureContextChanged()
        refresh()
    }

    func captureContextChanged() {
        contentRevision += 1
        if magnifierActive {
            stopCapture()
            refresh()
        }
    }

    func shutdown() {
        suspended = true
        magnifierActive = false
        stopCapture()
        ringWindow.orderOut(nil)
    }

    private var canMagnify: Bool { magnifierActive && settings.highlightEnabled && !suppressed && !suspended }

    private func updateAppearance() {
        setFrame(OverlayGeometry.ringFrame(cursor: cursor, settings: settings), on: ringWindow)
        ringView.update(settings: settings, clicks: clicks)
        if magnifierActive {
            lensWindow.setContentSize(settings.lensSize)
            lensView.update(shape: settings.magnifierShape)
        }
    }

    private func refresh() {
        guard settings.highlightEnabled, !suppressed, !suspended else {
            if ringWindow.isVisible { ringWindow.orderOut(nil) }
            return
        }
        if canMagnify {
            if ringWindow.isVisible { ringWindow.orderOut(nil) }
            updateLens()
        } else {
            setFrame(OverlayGeometry.ringFrame(cursor: cursor, settings: settings), on: ringWindow)
            ringView.update(settings: settings, clicks: clicks)
            if !ringWindow.isVisible { ringWindow.orderFrontRegardless() }
        }
    }

    private func updateLens() {
        guard let screen = screens.first(where: { $0.frame.contains(cursor) }) ?? screens.first,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            setMagnifierActive(false)
            return
        }
        let displayID = number.uint32Value
        if lensDisplay != displayID {
            stopCapture()
            lensDisplay = displayID
        }
        let size = OverlayGeometry.fittedLensSize(settings.lensSize, screen: screen.frame)
        setFrame(OverlayGeometry.lensFrame(cursor: cursor, size: size, screen: screen.frame), on: lensWindow)
        let source = OverlayGeometry.sourceRect(cursor: cursor, lensSize: size,
                                                zoom: settings.magnifierScale.scale, screen: screen.frame)
        captureUpdates.submit(CaptureRequest(displayID: displayID, sourceRect: source,
                                             pixelWidth: max(2, Int(ceil(source.width * screen.backingScaleFactor))),
                                             pixelHeight: max(2, Int(ceil(source.height * screen.backingScaleFactor))),
                                             excludedWindowIDs: [CGWindowID(ringWindow.windowNumber), CGWindowID(lensWindow.windowNumber)],
                                             contentRevision: contentRevision))
    }

    private func stopCapture() {
        captureUpdates.cancel()
        capture.setRequest(nil)
        lensWindow.orderOut(nil)
        lensView.clear()
        lensHasFrame = false
        lensDisplay = nil
    }

    private func setFrame(_ frame: CGRect, on window: NSWindow) {
        guard window.frame != frame else { return }
        if window.frame.size == frame.size { window.setFrameOrigin(frame.origin) }
        else { window.setFrame(frame, display: false) }
        windowMoveCount += 1
    }

    private static func makeWindow(title: String, shadow: Bool) -> NSPanel {
        let window = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                                  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = title
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = shadow
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isExcludedFromWindowsMenu = true
        window.sharingType = .readOnly
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.setAccessibilityElement(false)
        return window
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
