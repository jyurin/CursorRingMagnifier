import AppKit

final class MagnifierView: NSView {
    var image: CGImage? { didSet { needsDisplay = true } }
    var borderColor: NSColor = .white { didSet { needsDisplay = true } }
    var borderWidth: CGFloat = 3 { didSet { needsDisplay = true } }
    var shape: MagnifierShapePreset = .circle { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let clipPath = drawingPath(in: bounds)
        clipPath.addClip()

        if let image {
            NSGraphicsContext.current?.cgContext.draw(image, in: bounds)
        } else {
            NSColor.black.withAlphaComponent(0.25).setFill()
            bounds.fill()
        }

        borderColor.setStroke()
        let strokePath = drawingPath(in: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        strokePath.lineWidth = borderWidth
        strokePath.stroke()
    }

    private func drawingPath(in rect: CGRect) -> NSBezierPath {
        switch shape {
        case .circle:
            return NSBezierPath(ovalIn: rect)
        case .wideRectangle:
            return NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        }
    }
}
