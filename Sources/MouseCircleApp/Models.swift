import AppKit
import Foundation

struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.sRGB) ?? .systemBlue
        self.red = converted.redComponent.double
        self.green = converted.greenComponent.double
        self.blue = converted.blueComponent.double
        self.alpha = converted.alphaComponent.double
    }

    var nsColor: NSColor {
        NSColor(
            red: red.cgFloat,
            green: green.cgFloat,
            blue: blue.cgFloat,
            alpha: alpha.cgFloat
        )
    }

    static let presets: [RGBAColor] = [
        .init(red: 0.95, green: 0.20, blue: 0.20),
        .init(red: 0.12, green: 0.47, blue: 0.95),
        .init(red: 0.15, green: 0.70, blue: 0.30),
        .init(red: 0.98, green: 0.73, blue: 0.08),
        .init(red: 0.62, green: 0.32, blue: 0.88),
        .init(red: 0.98, green: 0.51, blue: 0.18),
        .init(red: 0.14, green: 0.76, blue: 0.84),
        .init(red: 0.95, green: 0.95, blue: 0.95)
    ]
}

enum RingSizePreset: String, CaseIterable, Codable, Identifiable {
    case small
    case medium
    case large
    case custom

    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .custom: return "Custom"
        }
    }
}

enum BorderWeightPreset: String, CaseIterable, Codable, Identifiable {
    case thin
    case regular
    case bold
    case custom

    var id: String { rawValue }
    var label: String {
        rawValue.capitalized
    }
}

enum MagnifierScalePreset: String, CaseIterable, Codable, Identifiable {
    case x125
    case x150
    case x200
    case x300

    var id: String { rawValue }
    var scale: CGFloat {
        switch self {
        case .x125: return 1.25
        case .x150: return 1.5
        case .x200: return 2.0
        case .x300: return 3.0
        }
    }

    var label: String {
        switch self {
        case .x125: return "1.25x"
        case .x150: return "1.5x"
        case .x200: return "2x"
        case .x300: return "3x"
        }
    }
}

enum MagnifierSizePreset: String, CaseIterable, Codable, Identifiable {
    case small
    case medium
    case large
    case xLarge
    case xxLarge

    var id: String { rawValue }

    var diameter: CGFloat {
        switch self {
        case .small: return 140
        case .medium: return 170
        case .large: return 220
        case .xLarge: return 280
        case .xxLarge: return 340
        }
    }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "X-Large"
        case .xxLarge: return "XX-Large"
        }
    }
}

enum MagnifierShapePreset: String, CaseIterable, Codable, Identifiable {
    case circle
    case wideRectangle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circle: return "Circle"
        case .wideRectangle: return "Wide Rectangle"
        }
    }

    var widthMultiplier: CGFloat {
        switch self {
        case .circle: return 1.0
        case .wideRectangle: return 1.8
        }
    }
}

enum ModifierKeyPreset: String, CaseIterable, Codable, Identifiable {
    case control
    case option
    case command
    case shift

    var id: String { rawValue }

    var label: String {
        switch self {
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        case .shift: return "Shift"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .command: return .command
        case .shift: return .shift
        }
    }
}

enum LetterKeyPreset: String, CaseIterable, Codable, Identifiable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var keyCode: UInt16 {
        switch self {
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        }
    }
}

struct AppSettings: Codable, Equatable {
    var highlightEnabled: Bool = true
    var ringSize: RingSizePreset = .large
    var ringCustomSize: Double = 88
    var borderWeight: BorderWeightPreset = .thin
    var borderCustomWidth: Double = 2
    var ringOpacity: Double = 0.60
    var ringColor: RGBAColor = .presets[2]
    var fillEnabled: Bool = false
    var fillOpacity: Double = 0.20
    var fillColor: RGBAColor = .presets[2]

    var clickFeedbackEnabled: Bool = true
    var clickShrinkAmount: Double = 0.82
    var clickDuration: Double = 0.16
    var normalClickColor: RGBAColor = .presets[1]
    var secondaryClickColor: RGBAColor = .presets[5]

    var magnifierScale: MagnifierScalePreset = .x125
    var magnifierSize: MagnifierSizePreset = .xxLarge
    var magnifierShape: MagnifierShapePreset = .wideRectangle
    var toggleShortcutModifier: ModifierKeyPreset = .control
    var toggleShortcutKey: LetterKeyPreset = .m
    var magnifierHoldModifier: ModifierKeyPreset = .control
    var startAtLogin: Bool = false

    var ringDiameter: CGFloat {
        switch ringSize {
        case .small: 44
        case .medium: 64
        case .large: 88
        case .custom: CGFloat(ringCustomSize)
        }
    }

    var ringLineWidth: CGFloat {
        switch borderWeight {
        case .thin: 2
        case .regular: 4
        case .bold: 6
        case .custom: CGFloat(borderCustomWidth)
        }
    }

    var lensSize: CGSize {
        CGSize(width: magnifierSize.diameter * magnifierShape.widthMultiplier, height: magnifierSize.diameter)
    }

    init() {}

    // Missing or invalid individual fields must not discard the user's other settings.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        highlightEnabled = read(.highlightEnabled, highlightEnabled)
        ringSize = read(.ringSize, ringSize)
        ringCustomSize = read(.ringCustomSize, ringCustomSize).clamped(to: 24...220, fallback: 88)
        borderWeight = read(.borderWeight, borderWeight)
        borderCustomWidth = read(.borderCustomWidth, borderCustomWidth).clamped(to: 1...20, fallback: 2)
        ringOpacity = read(.ringOpacity, ringOpacity).clamped(to: 0.1...1, fallback: 0.6)
        ringColor = read(.ringColor, ringColor).sanitized
        fillEnabled = read(.fillEnabled, fillEnabled)
        fillOpacity = read(.fillOpacity, fillOpacity).clamped(to: 0.05...1, fallback: 0.2)
        fillColor = read(.fillColor, fillColor).sanitized
        clickFeedbackEnabled = read(.clickFeedbackEnabled, clickFeedbackEnabled)
        clickShrinkAmount = read(.clickShrinkAmount, clickShrinkAmount).clamped(to: 0.7...0.95, fallback: 0.82)
        clickDuration = read(.clickDuration, clickDuration).clamped(to: 0.08...0.25, fallback: 0.16)
        normalClickColor = read(.normalClickColor, normalClickColor).sanitized
        secondaryClickColor = read(.secondaryClickColor, secondaryClickColor).sanitized
        magnifierScale = read(.magnifierScale, magnifierScale)
        magnifierSize = read(.magnifierSize, magnifierSize)
        magnifierShape = read(.magnifierShape, magnifierShape)
        toggleShortcutModifier = read(.toggleShortcutModifier, toggleShortcutModifier)
        toggleShortcutKey = read(.toggleShortcutKey, toggleShortcutKey)
        magnifierHoldModifier = read(.magnifierHoldModifier, magnifierHoldModifier)
        startAtLogin = read(.startAtLogin, startAtLogin)
    }
}

private extension RGBAColor {
    var sanitized: Self {
        .init(red: red.clamped(to: 0...1, fallback: 0), green: green.clamped(to: 0...1, fallback: 0),
              blue: blue.clamped(to: 0...1, fallback: 0), alpha: alpha.clamped(to: 0...1, fallback: 1))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>, fallback: Double) -> Double {
        isFinite ? min(range.upperBound, max(range.lowerBound, self)) : fallback
    }
}

private extension CGFloat {
    var double: Double { Double(self) }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}
