import AppKit
import QuartzCore

final class RingOverlayView: NSView {
    private struct Appearance: Equatable {
        let diameter: CGFloat
        let lineWidth: CGFloat
        let scale: CGFloat
        let stroke: RGBAColor
        let opacity: Double
        let fill: RGBAColor
        let fillOpacity: Double
        let fillEnabled: Bool
    }
    private let ring = CAShapeLayer()
    private var cachedAppearance: Appearance?
    private(set) var appearanceUpdateCount = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.addSublayer(ring)
    }

    required init?(coder: NSCoder) { nil }
    override var isOpaque: Bool { false }

    func update(settings: AppSettings, clicks: ClickState) {
        let next = Appearance(diameter: settings.ringDiameter, lineWidth: settings.ringLineWidth,
                              scale: clicks.scale(settings: settings), stroke: clicks.color(settings: settings),
                              opacity: settings.ringOpacity, fill: settings.fillColor,
                              fillOpacity: settings.fillOpacity, fillEnabled: settings.fillEnabled)
        guard next != cachedAppearance else { return }
        let previous = cachedAppearance
        let fromPath = ring.presentation()?.path ?? ring.path
        cachedAppearance = next
        appearanceUpdateCount += 1
        let diameter = next.diameter * next.scale
        let rect = CGRect(x: (bounds.width - diameter) / 2, y: (bounds.height - diameter) / 2,
                          width: diameter, height: diameter)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.removeAllAnimations()
        ring.frame = bounds
        ring.path = CGPath(ellipseIn: rect, transform: nil)
        ring.lineWidth = next.lineWidth
        ring.strokeColor = next.stroke.nsColor.withAlphaComponent(next.opacity).cgColor
        ring.fillColor = next.fillEnabled ? next.fill.nsColor.withAlphaComponent(next.fillOpacity).cgColor : nil
        CATransaction.commit()
        // Press animation holds its final appearance; releasing always restores immediately.
        if let previous, next.scale < previous.scale, let fromPath {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = fromPath
            animation.toValue = ring.path
            animation.duration = settings.clickDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.add(animation, forKey: "press")
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        ring.contentsScale = window?.backingScaleFactor ?? 2
    }
}
