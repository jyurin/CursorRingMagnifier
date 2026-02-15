import AppKit
import Foundation

let args = CommandLine.arguments
let outputDir = args.count > 1 ? args[1] : "build/AppIcon.iconset"
let fm = FileManager.default

try? fm.removeItem(atPath: outputDir)
try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let specs: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func point(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat) -> CGPoint {
    CGPoint(x: size * x, y: size * y)
}

for spec in specs {
    let size = CGFloat(spec.size)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: size * 0.22, yRadius: size * 0.22)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.63, blue: 0.49, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.42, blue: 0.93, alpha: 1)
    ])!.draw(in: bg, angle: -30)

    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.10, dy: size * 0.10), xRadius: size * 0.16, yRadius: size * 0.16).fill()

    let ringRect = CGRect(x: size * 0.19, y: size * 0.20, width: size * 0.56, height: size * 0.56)
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = max(2, size * 0.055)
    NSColor.white.withAlphaComponent(0.95).setStroke()
    ring.stroke()

    NSColor.white.withAlphaComponent(0.16).setFill()
    NSBezierPath(ovalIn: ringRect.insetBy(dx: size * 0.07, dy: size * 0.07)).fill()

    let lensDiameter = size * 0.30
    let lensCenter = point(0.66, 0.34, size)
    let lensRect = CGRect(
        x: lensCenter.x - lensDiameter / 2,
        y: lensCenter.y - lensDiameter / 2,
        width: lensDiameter,
        height: lensDiameter
    )

    let lens = NSBezierPath(ovalIn: lensRect)
    lens.lineWidth = max(1.5, size * 0.032)
    NSColor.white.withAlphaComponent(0.96).setStroke()
    NSColor.white.withAlphaComponent(0.24).setFill()
    lens.fill()
    lens.stroke()

    let sparkle = NSBezierPath(ovalIn: lensRect.insetBy(dx: size * 0.10, dy: size * 0.10).offsetBy(dx: -size * 0.03, dy: size * 0.03))
    NSColor.white.withAlphaComponent(0.25).setFill()
    sparkle.fill()

    let handleStart = CGPoint(
        x: lensCenter.x + lensDiameter * 0.27,
        y: lensCenter.y - lensDiameter * 0.27
    )
    let handleEnd = point(0.86, 0.13, size)

    let handleShadow = NSBezierPath()
    handleShadow.move(to: handleStart)
    handleShadow.line(to: handleEnd)
    handleShadow.lineWidth = max(3, size * 0.055)
    handleShadow.lineCapStyle = .round
    NSColor.black.withAlphaComponent(0.18).setStroke()
    handleShadow.stroke()

    let handle = NSBezierPath()
    handle.move(to: handleStart)
    handle.line(to: handleEnd)
    handle.lineWidth = max(2.5, size * 0.045)
    handle.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.95).setStroke()
    handle.stroke()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        continue
    }

    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(spec.name)
    try png.write(to: url)
}
