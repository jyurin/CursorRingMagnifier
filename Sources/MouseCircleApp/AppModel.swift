import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var magnifierHolding = false
    @Published private(set) var captureError: String?
    @Published private(set) var loginError: String?

    let settingsStore = SettingsStore()
    let permissions = PermissionsModel()
    private let overlays = OverlayWindowManager()
    private let monitors = InputMonitors()
    private let screenshot = ScreenshotGuard()
    private var settings = AppSettings()
    private var modifiers: NSEvent.ModifierFlags = []
    private var suspended = false
    private enum SuspensionReason: Hashable { case systemSleep, displaySleep, inactiveSession }
    private var suspensionReasons = Set<SuspensionReason>()
    private var holdWatchdog: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = settingsStore.settings
        monitors.onCursorMoved = { [weak self] point in self?.overlays.moveCursor(to: point) }
        monitors.onClickStateChanged = { [weak self] pressed, secondary in
            guard let self else { return }
            if !pressed { self.screenshot.mouseUp() }
            guard self.permissions.accessibilityGranted, !self.suspended else { return }
            self.overlays.setClick(pressed: pressed, secondary: secondary)
        }
        monitors.onModifierFlagsChanged = { [weak self] flags in
            guard let self else { return }
            self.modifiers = flags
            self.screenshot.modifiersChanged(flags)
            self.updateMagnifier()
        }
        monitors.onKeyDown = { [weak self] key, flags in
            guard let self else { return }
            self.screenshot.keyDown(key, flags: flags)
            guard key == self.settings.toggleShortcutKey.keyCode,
                  flags.intersection([.control, .option, .command, .shift]) == self.settings.toggleShortcutModifier.flag,
                  self.permissions.accessibilityGranted else { return }
            self.settingsStore.settings.highlightEnabled.toggle()
        }
        screenshot.onChange = { [weak self] hidden in
            guard let self else { return }
            self.overlays.setSuppressed(hidden)
            self.updatePointerTracking()
            self.updateMagnifier()
        }
        overlays.onCaptureFailure = { [weak self] message in
            self?.captureError = message
            self?.setMagnifier(false)
        }
        monitors.start()
        settingsStore.$settings.removeDuplicates().sink { [weak self] value in
            guard let self else { return }
            let loginChanged = self.settings.startAtLogin != value.startAtLogin
            self.settings = value
            self.overlays.apply(value)
            self.updatePointerTracking()
            self.updateMagnifier()
            if loginChanged { self.configureStartAtLogin(value.startAtLogin) }
        }.store(in: &cancellables)
        configureStartAtLogin(settings.startAtLogin)

        permissions.$accessibilityGranted.combineLatest(permissions.$screenRecordingGranted)
            .removeDuplicates(by: ==)
            .receive(on: RunLoop.main)
            .sink { [weak self] accessibility, recording in
                guard let self else { return }
                if !accessibility { self.overlays.resetClicks() }
                if !accessibility || !recording { self.setMagnifier(false) }
                if !self.suspended {
                    self.monitors.stop()
                    self.monitors.start()
                    self.updatePointerTracking()
                }
            }.store(in: &cancellables)
        observeLifecycle()
    }

    func captureContextChanged() { overlays.captureContextChanged() }

    func shutdown() {
        suspended = true
        modifiers = []
        holdWatchdog?.invalidate()
        holdWatchdog = nil
        settingsStore.flush()
        monitors.stop()
        screenshot.reset()
        overlays.shutdown()
        cancellables.removeAll()
    }

    private func updatePointerTracking() {
        monitors.setPointerTracking(settings.highlightEnabled && !suspended && !screenshot.isHidden)
    }

    private func updateMagnifier() {
        let hold = modifiers.intersection([.control, .option, .command, .shift]) == settings.magnifierHoldModifier.flag
        let active = hold && settings.highlightEnabled && !suspended && !screenshot.isHidden &&
            permissions.accessibilityGranted && permissions.screenRecordingGranted
        setMagnifier(active)
    }

    private func setMagnifier(_ active: Bool) {
        guard active != magnifierHolding else { return }
        magnifierHolding = active
        if active {
            captureError = nil
            overlays.moveCursor(to: NSEvent.mouseLocation)
            // Runs only while magnifying; recover even if another app swallows the key-up event.
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.modifiers = NSEvent.modifierFlags
                    self.updateMagnifier()
                }
            }
            timer.tolerance = 0.05
            holdWatchdog = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            holdWatchdog?.invalidate()
            holdWatchdog = nil
        }
        overlays.setMagnifierActive(active)
    }

    private func configureStartAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        loginError = nil
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
                if service.status == .requiresApproval {
                    loginError = "システム設定の「一般 > ログイン項目」で、このアプリの自動起動を許可してください。"
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            loginError = "自動起動の設定を変更できませんでした。アプリをアプリケーションフォルダに入れて再度お試しください。\n\(error.localizedDescription)"
        }
    }

    private func observeLifecycle() {
        observe(NSApplication.didBecomeActiveNotification, center: .default) { [weak self] _ in
            self?.permissions.refresh()
        }
        observe(NSApplication.didChangeScreenParametersNotification, center: .default) { [weak self] _ in
            self?.overlays.screensChanged()
        }
        observe(NSWindow.didBecomeKeyNotification, center: .default) { notification in
            (notification.object as? NSWindow)?.acceptsMouseMovedEvents = true
        }
        // AppKit posts this on the main thread. Do not defer the last settings flush to a later run-loop turn.
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.shutdown() }
            .store(in: &cancellables)
        let workspace = NSWorkspace.shared.notificationCenter
        let lifecycle: [(Notification.Name, Notification.Name, SuspensionReason)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .displaySleep),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession)
        ]
        for (pause, resume, reason) in lifecycle {
            observe(pause, center: workspace) { [weak self] _ in
                self?.suspensionReasons.insert(reason)
                self?.suspend()
            }
            observe(resume, center: workspace) { [weak self] _ in
                self?.suspensionReasons.remove(reason)
                if self?.suspensionReasons.isEmpty == true { self?.resume() }
            }
        }
        observe(NSWorkspace.didActivateApplicationNotification, center: workspace) { [weak self] _ in
            self?.permissions.refresh(force: false)
        }
        observe(NSWorkspace.activeSpaceDidChangeNotification, center: workspace) { [weak self] _ in
            self?.overlays.moveCursor(to: NSEvent.mouseLocation)
        }
        observe(NSWorkspace.didTerminateApplicationNotification, center: workspace) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == "com.apple.screencaptureui" { self?.screenshot.screenshotApplicationEnded() }
        }
    }

    private func observe(_ name: Notification.Name, center: NotificationCenter, action: @escaping (Notification) -> Void) {
        center.publisher(for: name).receive(on: RunLoop.main).sink(receiveValue: action).store(in: &cancellables)
    }

    private func suspend() {
        guard !suspended else { return }
        suspended = true
        modifiers = []
        setMagnifier(false)
        monitors.stop()
        screenshot.reset()
        overlays.setSuspended(true)
        settingsStore.flush()
    }

    private func resume() {
        guard suspended else { return }
        suspended = false
        permissions.refresh()
        overlays.setSuspended(false)
        monitors.start()
        updatePointerTracking()
    }
}
