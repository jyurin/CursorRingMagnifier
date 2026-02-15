import AppKit
import SwiftUI

@main
struct MouseCircleMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Cursor Ring", systemImage: "scope") {
            Toggle("Cursor Highlight", isOn: Binding(
                get: { model.settingsStore.settings.highlightEnabled },
                set: { model.settingsStore.settings.highlightEnabled = $0 }
            ))

            Toggle("Magnifier (hold \(model.settingsStore.settings.magnifierHoldModifier.label))", isOn: .constant(model.magnifierHolding))
                .disabled(true)

            Divider()

            Toggle("Start at Login", isOn: Binding(
                get: { model.settingsStore.settings.startAtLogin },
                set: { model.settingsStore.settings.startAtLogin = $0 }
            ))

            Button("Settings...") {
                appDelegate.openSettings(with: model)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}
