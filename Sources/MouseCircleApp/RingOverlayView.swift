import AppKit

final class RingOverlayView: NSView {
    var cursorLocationInWindow: CGPoint = .zero { didSet { needsDisplay = true } }
    var ringColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    var ringOpacity: CGFloat = 1.0 { didSet { needsDisplay = true } }
    var fillEnabled: Bool = false { didSet { needsDisplay = true } }
    var fillColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    var fillOpacity: CGFloat = 0.2 { didSet { needsDisplay = true } }
    var ringDiameter: CGFloat = 64 { didSet { needsDisplay = true } }
    var lineWidth: CGFloat = 4 { didSet { needsDisplay = true } }
    var scale: CGFloat = 1.0 { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let drawDiameter = ringDiameter * max(0.1, scale)
        let rect = CGRect(
            x: cursorLocationInWindow.x - drawDiameter / 2,
            y: cursorLocationInWindow.y - drawDiameter / 2,
            width: drawDiameter,
            height: drawDiameter
        )

        let path = NSBezierPath(ovalIn: rect)
        if fillEnabled {
            fillColor.withAlphaComponent(fillOpacity).setFill()
            path.fill()
        }

        path.lineWidth = lineWidth
        ringColor.withAlphaComponent(ringOpacity).setStroke()
        path.stroke()
    }
}
