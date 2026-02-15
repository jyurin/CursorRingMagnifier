import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var magnifierHolding = false

    let settingsStore = SettingsStore()
    let permissions = PermissionsModel()

    private let overlays = OverlayWindowManager()
    private let monitors = InputMonitors()
    private var cancellables = Set<AnyCancellable>()

    init() {
        configureStartAtLogin(settingsStore.settings.startAtLogin)

        monitors.onCursorMoved = { [weak self] location in
            guard let self else { return }
            self.overlays.updateCursor(location: location, settings: self.settingsStore.settings)
        }

        monitors.onClickStateChanged = { [weak self] isPressed, isSecondary in
            guard let self else { return }
            self.permissions.refresh()
            guard self.permissions.accessibilityGranted else { return }
            self.overlays.setClickFeedbackPressed(
                isPressed,
                isSecondary: isSecondary,
                settings: self.settingsStore.settings
            )
        }

        monitors.onModifierFlagsChanged = { [weak self] flags in
            guard let self else { return }
            self.handleMagnifierFlags(flags)
        }
        monitors.onKeyDown = { [weak self] keyCode, flags in
            guard let self else { return }
            self.handleScreenshotShortcut(keyCode: keyCode, flags: flags)
            self.handleToggleShortcut(keyCode: keyCode, flags: flags)
        }

        monitors.start()
        overlays.rebuildRingWindows()

        settingsStore.$settings.sink { [weak self] settings in
            guard let self else { return }
            self.overlays.updateCursor(location: NSEvent.mouseLocation, settings: settings)
            self.configureStartAtLogin(settings.startAtLogin)
            if !settings.highlightEnabled {
                self.magnifierHolding = false
                self.overlays.setMagnifierActive(false, settings: settings)
            } else if !self.magnifierHolding {
                self.overlays.setMagnifierActive(false, settings: settings)
            }
        }.store(in: &cancellables)
    }

    func configureStartAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Ignore registration errors in MVP; UI remains responsive.
            }
        }
    }

    private func handleMagnifierFlags(_ flags: NSEvent.ModifierFlags) {
        let settings = settingsStore.settings
        let active = flags.contains(settings.magnifierHoldModifier.flag)
        permissions.refresh()
        guard settings.highlightEnabled, permissions.accessibilityGranted, permissions.screenRecordingGranted else {
            magnifierHolding = false
            overlays.setMagnifierActive(false, settings: settings)
            return
        }
        magnifierHolding = active
        overlays.setMagnifierActive(active, settings: settings)
    }

    private func handleToggleShortcut(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        let settings = settingsStore.settings
        guard keyCode == settings.toggleShortcutKey.keyCode else { return }
        guard flags.contains(settings.toggleShortcutModifier.flag) else { return }
        permissions.refresh()
        guard permissions.accessibilityGranted else { return }
        settingsStore.settings.highlightEnabled.toggle()
    }

    private func handleScreenshotShortcut(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        let screenshotKeys: Set<UInt16> = [18, 19, 20, 21, 23, 22] // 1...6
        guard screenshotKeys.contains(keyCode) else { return }
        guard flags.contains(.command), flags.contains(.shift) else { return }
        overlays.hideRingTemporarily(duration: 1.8, settings: settingsStore.settings)
    }
}
