import AppKit
import Testing
@testable import MouseCircleApp

struct SettingsAndGeometryTests {
    @Test func defaultsAreUnchanged() {
        let settings = AppSettings()
        #expect(settings.ringColor == RGBAColor.presets[2])
        #expect(settings.ringSize == .large)
        #expect(settings.borderWeight == .thin)
        #expect(settings.ringOpacity == 0.6)
        #expect(settings.fillOpacity == 0.2)
        #expect(settings.fillColor == RGBAColor.presets[2])
        #expect(settings.normalClickColor == RGBAColor.presets[1])
        #expect(settings.secondaryClickColor == RGBAColor.presets[5])
        #expect(settings.toggleShortcutModifier == .control && settings.toggleShortcutKey == .m)
        #expect(settings.magnifierHoldModifier == .control)
        #expect(settings.magnifierScale == .x125 && settings.magnifierSize == .xxLarge)
        #expect(settings.magnifierShape == .wideRectangle)
    }

    @Test func allSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.highlightEnabled = false
        settings.ringSize = .custom
        settings.ringCustomSize = 179
        settings.borderWeight = .custom
        settings.borderCustomWidth = 12.5
        settings.ringOpacity = 0.34
        settings.ringColor = RGBAColor(red: 0.4, green: 0.2, blue: 0.7)
        settings.fillEnabled = true
        settings.fillOpacity = 0.41
        settings.fillColor = .presets[3]
        settings.clickFeedbackEnabled = false
        settings.clickShrinkAmount = 0.75
        settings.clickDuration = 0.24
        settings.normalClickColor = .presets[5]
        settings.secondaryClickColor = .presets[0]
        settings.magnifierScale = .x300
        settings.magnifierSize = .small
        settings.magnifierShape = .circle
        settings.toggleShortcutModifier = .command
        settings.toggleShortcutKey = .z
        settings.magnifierHoldModifier = .option
        settings.startAtLogin = true
        #expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func partialLegacySettingsKeepValidValues() throws {
        let data = Data(#"{"ringSize":"custom","ringCustomSize":153,"ringColor":{"red":0.2,"green":0.4,"blue":0.8,"alpha":1},"magnifierScale":"x300","startAtLogin":true}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.ringCustomSize == 153)
        #expect(settings.ringSize == .custom)
        #expect(settings.ringColor.blue == 0.8)
        #expect(settings.magnifierScale == .x300)
        #expect(settings.startAtLogin)
        #expect(settings.magnifierShape == .wideRectangle)
    }

    @Test func invalidFieldsDoNotResetEverything() throws {
        let data = Data(#"{"ringSize":"future-shape","ringCustomSize":9000,"borderCustomWidth":-5,"fillOpacity":-1,"magnifierScale":"x150","toggleShortcutKey":"b"}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.ringSize == .large)
        #expect(settings.ringCustomSize == 220)
        #expect(settings.borderCustomWidth == 1)
        #expect(settings.fillOpacity == 0.05)
        #expect(settings.magnifierScale == .x150)
        #expect(settings.toggleShortcutKey == .b)
    }

    @Test @MainActor func sliderWritesAreBatchedAndFlushRestores() throws {
        let name = "CursorRingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        store.settings.ringSize = .custom
        for value in 24...220 { store.settings.ringCustomSize = Double(value) }
        #expect(store.saveCount == 0)
        store.flush()
        #expect(store.saveCount == 1)
        #expect(SettingsStore(defaults: defaults).settings == store.settings)
        store.flush()
        #expect(store.saveCount == 1)
    }

    @Test func clickAppearanceLastsUntilReleaseAndRightHasPriority() {
        let settings = AppSettings()
        var state = ClickState()
        state.set(pressed: true, secondary: false)
        for _ in 0..<1000 {
            #expect(state.scale(settings: settings) == CGFloat(settings.clickShrinkAmount))
            #expect(state.color(settings: settings) == settings.normalClickColor)
        }
        state.set(pressed: true, secondary: true)
        #expect(state.color(settings: settings) == settings.secondaryClickColor)
        state.set(pressed: false, secondary: true)
        #expect(state.color(settings: settings) == settings.normalClickColor)
        state.set(pressed: false, secondary: false)
        #expect(state.scale(settings: settings) == 1)
        #expect(state.color(settings: settings) == settings.ringColor)
    }

    @Test func disabledFeedbackUsesNormalAppearance() {
        var settings = AppSettings()
        settings.clickFeedbackEnabled = false
        let state = ClickState(left: true, right: true)
        #expect(state.scale(settings: settings) == 1)
        #expect(state.color(settings: settings) == settings.ringColor)
    }

    @Test(arguments: MagnifierSizePreset.allCases, MagnifierScalePreset.allCases)
    func zoomIsCorrectForEverySize(size: MagnifierSizePreset, scale: MagnifierScalePreset) {
        var settings = AppSettings()
        settings.magnifierSize = size
        settings.magnifierScale = scale
        for shape in MagnifierShapePreset.allCases {
            settings.magnifierShape = shape
            let screen = CGRect(x: -1920, y: 100, width: 1920, height: 1080)
            let cursor = CGPoint(x: -1000, y: 650)
            let rect = OverlayGeometry.sourceRect(cursor: cursor, lensSize: settings.lensSize, zoom: scale.scale, screen: screen)
            #expect(abs(settings.lensSize.width / rect.width - scale.scale) < 0.0001)
            #expect(abs(settings.lensSize.height / rect.height - scale.scale) < 0.0001)
            #expect(abs(rect.midX - 920) < 0.001)
            #expect(abs(rect.midY - 530) < 0.001)
        }
    }

    @Test func captureAtEdgesClampsWithoutStretching() {
        let screen = CGRect(x: 300, y: -1000, width: 1920, height: 1080)
        let localBounds = CGRect(origin: .zero, size: screen.size)
        let size = AppSettings().lensSize
        for x in [screen.minX, screen.maxX] {
            for y in [screen.minY, screen.maxY] {
                let cursor = CGPoint(x: x, y: y)
                let crop = OverlayGeometry.sourceRect(cursor: cursor, lensSize: size, zoom: 2, screen: screen)
                #expect(localBounds.contains(crop))
                #expect(crop.width == size.width / 2 && crop.height == size.height / 2)
                #expect(screen.contains(OverlayGeometry.lensFrame(cursor: cursor, size: size, screen: screen)))
            }
        }
    }

    @Test func ringBufferIsOnlyTheRingBounds() {
        var settings = AppSettings()
        let point = CGPoint(x: -500, y: 900)
        #expect(OverlayGeometry.ringFrame(cursor: point, settings: settings).width == 98)
        settings.ringSize = .custom
        settings.ringCustomSize = 220
        settings.borderWeight = .custom
        settings.borderCustomWidth = 20
        let frame = OverlayGeometry.ringFrame(cursor: point, settings: settings)
        #expect(frame.size == CGSize(width: 248, height: 248))
        #expect(frame.midX == point.x && frame.midY == point.y)
    }

    @Test func largeLensFitsSmallDisplayWithoutChangingShape() {
        let screen = CGRect(x: -500, y: -300, width: 500, height: 300)
        let desired = AppSettings().lensSize
        let fitted = OverlayGeometry.fittedLensSize(desired, screen: screen)
        #expect(fitted.width <= screen.width && fitted.height <= screen.height)
        #expect(abs(fitted.width / fitted.height - 1.8) < 0.001)
        let frame = OverlayGeometry.lensFrame(cursor: screen.origin, size: fitted, screen: screen)
        #expect(screen.contains(frame))
    }
}
