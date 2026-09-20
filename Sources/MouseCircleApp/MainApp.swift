import AppKit
import SwiftUI

@main
struct MouseCircleMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Cursor Ring", systemImage: "scope") {
            MenuContent(model: model, settings: model.settingsStore) { appDelegate.openSettings(with: model) }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    let openSettings: () -> Void

    var body: some View {
        Toggle("マウスリングを表示", isOn: $settings.settings.highlightEnabled)
        Text("拡大鏡: \(model.magnifierHolding ? "表示中" : settings.settings.magnifierHoldModifier.label + " を長押し")")
        if model.captureError != nil {
            Button("拡大鏡の状態を設定で確認…", action: openSettings)
        }
        Divider()
        Toggle("ログイン時に自動起動", isOn: $settings.settings.startAtLogin)
        Button("設定…", action: openSettings)
        Divider()
        Button("終了") {
            model.shutdown()
            NSApplication.shared.terminate(nil)
        }
    }
}
