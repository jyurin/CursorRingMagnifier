import AppKit
import AVFoundation
import QuartzCore

final class MagnifierView: NSView {
    private let video = AVSampleBufferDisplayLayer()
    private let clip = CAShapeLayer()
    private let border = CAShapeLayer()
    private var shape: MagnifierShapePreset = .circle

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        video.videoGravity = .resizeAspectFill
        video.mask = clip
        layer?.addSublayer(video)
        border.fillColor = nil
        border.strokeColor = NSColor.white.cgColor
        border.lineWidth = 3
        layer?.addSublayer(border)
    }

    required init?(coder: NSCoder) { nil }
    override var isOpaque: Bool { false }

    func update(shape: MagnifierShapePreset) {
        self.shape = shape
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        video.frame = bounds
        clip.frame = video.bounds
        clip.path = path(in: video.bounds)
        border.frame = bounds
        border.path = path(in: bounds.insetBy(dx: 1.5, dy: 1.5))
        CATransaction.commit()
    }

    @discardableResult
    func display(_ buffer: CMSampleBuffer) -> Bool {
        // Display live IOSurfaces directly; no full-screen CGImage allocation or CPU crop.
        if video.status == .failed { video.flush() }
        guard video.isReadyForMoreMediaData else { return false }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true), CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        video.enqueue(buffer)
        return true
    }

    func clear() { video.flushAndRemoveImage() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        border.contentsScale = window?.backingScaleFactor ?? 2
    }

    private func path(in rect: CGRect) -> CGPath {
        switch shape {
        case .circle: CGPath(ellipseIn: rect, transform: nil)
        case .wideRectangle: CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        }
    }
}
