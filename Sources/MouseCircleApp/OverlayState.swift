import AppKit

struct ClickState: Equatable {
    var left = false
    var right = false

    mutating func set(pressed: Bool, secondary: Bool) {
        if secondary { right = pressed } else { left = pressed }
    }

    func scale(settings: AppSettings) -> CGFloat {
        settings.clickFeedbackEnabled && (left || right) ? settings.clickShrinkAmount : 1
    }

    func color(settings: AppSettings) -> RGBAColor {
        guard settings.clickFeedbackEnabled else { return settings.ringColor }
        if right { return settings.secondaryClickColor }
        if left { return settings.normalClickColor }
        return settings.ringColor
    }
}

enum OverlayGeometry {
    static func fittedLensSize(_ size: CGSize, screen: CGRect) -> CGSize {
        let fit = min(1, screen.width / size.width, screen.height / size.height)
        return CGSize(width: size.width * fit, height: size.height * fit)
    }

    static func ringFrame(cursor: CGPoint, settings: AppSettings) -> CGRect {
        let side = ceil(settings.ringDiameter + settings.ringLineWidth + 8)
        return CGRect(x: cursor.x - side / 2, y: cursor.y - side / 2, width: side, height: side)
    }

    static func lensFrame(cursor: CGPoint, size: CGSize, screen: CGRect) -> CGRect {
        let offset = max(48, size.height * 0.32)
        return CGRect(x: clamp(cursor.x - size.width / 2, min: screen.minX, max: screen.maxX - size.width),
                      y: clamp(cursor.y - size.height / 2 - offset, min: screen.minY, max: screen.maxY - size.height),
                      width: size.width, height: size.height)
    }

    // ScreenCaptureKit uses display-local points with a top-left origin, not Retina pixels.
    static func sourceRect(cursor: CGPoint, lensSize: CGSize, zoom: CGFloat, screen: CGRect) -> CGRect {
        let width = min(screen.width, lensSize.width / zoom)
        let height = min(screen.height, lensSize.height / zoom)
        return CGRect(x: clamp(cursor.x - screen.minX - width / 2, min: 0, max: screen.width - width),
                      y: clamp(screen.maxY - cursor.y - height / 2, min: 0, max: screen.height - height),
                      width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        max(lower, min(max(lower, upper), value))
    }
}

// Event-driven: at most one pending delivery, and no repeating timer when the mouse is still.
@MainActor
final class FrameCoalescer<Value: Equatable> {
    var deliver: ((Value) -> Void)?
    private let interval: TimeInterval
    private var pending: Value?
    private var lastValue: Value?
    private var lastDelivery = -Double.infinity
    private var work: DispatchWorkItem?

    init(framesPerSecond: Double) { interval = 1 / framesPerSecond }

    func submit(_ value: Value) {
        pending = value
        guard work == nil else { return }
        let delay = max(0, interval - (ProcessInfo.processInfo.systemUptime - lastDelivery))
        if delay == 0 {
            flush()
        } else {
            let next = DispatchWorkItem { [weak self] in self?.flush() }
            work = next
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: next)
        }
    }

    func cancel() {
        work?.cancel()
        work = nil
        pending = nil
        lastValue = nil
        lastDelivery = -Double.infinity
    }

    private func flush() {
        work = nil
        guard let value = pending else { return }
        pending = nil
        guard value != lastValue else { return }
        lastValue = value
        lastDelivery = ProcessInfo.processInfo.systemUptime
        deliver?(value)
    }
}
