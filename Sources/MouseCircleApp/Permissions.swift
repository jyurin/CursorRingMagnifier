import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class PermissionsModel: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var screenRecordingGranted = false
    private var lastRefresh = -Double.infinity

    init() {
        refresh()
    }

    func refresh(force: Bool = true) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastRefresh > 3 else { return }
        lastRefresh = now
        let accessibility = AXIsProcessTrusted()
        let recording = CGPreflightScreenCaptureAccess()
        if accessibilityGranted != accessibility { accessibilityGranted = accessibility }
        if screenRecordingGranted != recording { screenRecordingGranted = recording }
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }
}
