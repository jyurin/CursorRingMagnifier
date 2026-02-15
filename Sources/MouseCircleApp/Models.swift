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

struct AppSettings: Codable {
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
}

private extension CGFloat {
    var double: Double { Double(self) }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}
