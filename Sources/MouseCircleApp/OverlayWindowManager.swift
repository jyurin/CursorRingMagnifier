import AppKit
import Foundation

@MainActor
final class OverlayWindowManager {
    private struct RingWindowEntry {
        let screen: NSScreen
        let window: NSWindow
        let view: RingOverlayView
    }

    private var ringWindows: [RingWindowEntry] = []
    private var magnifierWindow: NSWindow?
    private var magnifierView: MagnifierView?
    private var magnifierTimer: Timer?

    private var cursorLocation: CGPoint = .zero
    private var magnifierActive = false
    private var ringScale: CGFloat = 1.0
    private var ringColorOverride: NSColor?
    private var leftButtonPressed = false
    private var rightButtonPressed = false
    private var temporarilyHiddenUntil: Date?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildRingWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    func rebuildRingWindows() {
        ringWindows.forEach { $0.window.orderOut(nil) }
        ringWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.sharingType = .none
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let view = RingOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            window.contentView = view
            window.orderFrontRegardless()

            ringWindows.append(RingWindowEntry(screen: screen, window: window, view: view))
        }
    }

    func updateCursor(location: CGPoint, settings: AppSettings) {
        cursorLocation = location
        if ringWindows.isEmpty {
            rebuildRingWindows()
        }

        for entry in ringWindows {
            entry.window.setFrame(entry.screen.frame, display: false)
            entry.view.frame = CGRect(origin: .zero, size: entry.screen.frame.size)
            entry.view.isHidden = !settings.highlightEnabled || magnifierActive || isTemporarilyHidden
            entry.view.cursorLocationInWindow = CGPoint(
                x: location.x - entry.screen.frame.minX,
                y: location.y - entry.screen.frame.minY
            )
            entry.view.ringColor = ringColorOverride ?? settings.ringColor.nsColor
            entry.view.ringOpacity = CGFloat(settings.ringOpacity)
            entry.view.fillEnabled = settings.fillEnabled
            entry.view.fillColor = settings.fillColor.nsColor
            entry.view.fillOpacity = CGFloat(settings.fillOpacity)
            entry.view.ringDiameter = ringDiameter(for: settings)
            entry.view.lineWidth = lineWidth(for: settings)
            entry.view.scale = ringScale
        }

        if magnifierWindow != nil {
            updateMagnifierAppearance(settings: settings)
            updateMagnifierWindowPosition()
        }
    }

    func setClickFeedbackPressed(_ isPressed: Bool, isSecondary: Bool, settings: AppSettings) {
        guard settings.clickFeedbackEnabled else {
            ringScale = 1.0
            ringColorOverride = nil
            return
        }

        if isSecondary {
            rightButtonPressed = isPressed
        } else {
            leftButtonPressed = isPressed
        }

        let anyPressed = leftButtonPressed || rightButtonPressed
        if anyPressed {
            ringScale = CGFloat(settings.clickShrinkAmount)
            ringColorOverride = rightButtonPressed ? settings.secondaryClickColor.nsColor : settings.normalClickColor.nsColor
        } else {
            ringScale = 1.0
            ringColorOverride = nil
        }
    }

    func setMagnifierActive(_ active: Bool, settings: AppSettings) {
        magnifierActive = active
        if active {
            createMagnifierIfNeeded(size: magnifierSize(for: settings))
            updateMagnifierAppearance(settings: settings)
            updateMagnifierWindowPosition()
            startMagnifierUpdates(scale: settings.magnifierScale.scale)
            magnifierWindow?.orderFrontRegardless()
        } else {
            stopMagnifierUpdates()
            magnifierWindow?.orderOut(nil)
        }
        updateCursor(location: cursorLocation, settings: settings)
    }

    func hideRingTemporarily(duration: TimeInterval, settings: AppSettings) {
        temporarilyHiddenUntil = Date().addingTimeInterval(duration)
        updateCursor(location: cursorLocation, settings: settings)
    }

    private func createMagnifierIfNeeded(size: CGSize) {
        guard magnifierWindow == nil else { return }

        let rect = CGRect(
            x: cursorLocation.x - size.width / 2,
            y: cursorLocation.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = MagnifierView(frame: CGRect(origin: .zero, size: rect.size))
        window.contentView = view

        magnifierWindow = window
        magnifierView = view
    }

    private func updateMagnifierWindowPosition() {
        guard let magnifierWindow else { return }
        let size = magnifierWindow.frame.size
        let offset = max(48.0, size.height * 0.32)
        let newOrigin = CGPoint(
            x: cursorLocation.x - size.width / 2,
            y: cursorLocation.y - size.height / 2 - offset
        )
        magnifierWindow.setFrameOrigin(newOrigin)
    }

    private func updateMagnifierAppearance(settings: AppSettings) {
        guard let magnifierWindow, let magnifierView else { return }
        magnifierView.shape = settings.magnifierShape

        let targetSize = magnifierSize(for: settings)
        let current = magnifierWindow.frame.size
        if abs(current.width - targetSize.width) < 0.5, abs(current.height - targetSize.height) < 0.5 {
            return
        }

        var frame = magnifierWindow.frame
        frame.origin.x += (current.width - targetSize.width) / 2
        frame.origin.y += (current.height - targetSize.height) / 2
        frame.size = targetSize
        magnifierWindow.setFrame(frame, display: true)
        magnifierView.frame = CGRect(origin: .zero, size: frame.size)
    }

    private func startMagnifierUpdates(scale: CGFloat) {
        stopMagnifierUpdates()

        magnifierTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.captureMagnifierImage(scale: scale)
            }
        }
    }

    private func stopMagnifierUpdates() {
        magnifierTimer?.invalidate()
        magnifierTimer = nil
    }

    private func captureMagnifierImage(scale: CGFloat) {
        guard let magnifierView else { return }
        guard let screen = screenContainingCursor() else {
            magnifierView.image = nil
            return
        }
        guard let displayID = displayID(for: screen) else {
            magnifierView.image = nil
            return
        }
        guard let displayImage = CGDisplayCreateImage(displayID) else {
            magnifierView.image = nil
            return
        }

        let scaleFactor = screen.backingScaleFactor
        let sampleHeightPoints: CGFloat = 150 / scale
        let sampleWidthPoints = sampleHeightPoints * settingsAspectMultiplier()
        let sampleWidthPixels = sampleWidthPoints * scaleFactor
        let sampleHeightPixels = sampleHeightPoints * scaleFactor

        let localX = (cursorLocation.x - screen.frame.minX) * scaleFactor
        let localYFromBottom = (cursorLocation.y - screen.frame.minY) * scaleFactor
        let imageHeight = CGFloat(displayImage.height)
        let localYFromTop = imageHeight - localYFromBottom

        var cropRect = CGRect(
            x: localX - sampleWidthPixels / 2,
            y: localYFromTop - sampleHeightPixels / 2,
            width: sampleWidthPixels,
            height: sampleHeightPixels
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: CGFloat(displayImage.width), height: imageHeight)
        cropRect = cropRect.intersection(imageBounds)
        guard !cropRect.isNull, cropRect.width > 1, cropRect.height > 1 else {
            magnifierView.image = nil
            return
        }

        magnifierView.image = displayImage.cropping(to: cropRect)
    }

    private func screenContainingCursor() -> NSScreen? {
        for screen in NSScreen.screens where screen.frame.contains(cursorLocation) {
            return screen
        }
        return NSScreen.main
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func magnifierSize(for settings: AppSettings) -> CGSize {
        let height = settings.magnifierSize.diameter
        return CGSize(width: height * settings.magnifierShape.widthMultiplier, height: height)
    }

    private func ringDiameter(for settings: AppSettings) -> CGFloat {
        switch settings.ringSize {
        case .small: return 44
        case .medium: return 64
        case .large: return 88
        case .custom: return CGFloat(settings.ringCustomSize)
        }
    }

    private func settingsAspectMultiplier() -> CGFloat {
        guard let magnifierView else { return 1.0 }
        return magnifierView.shape.widthMultiplier
    }

    private var isTemporarilyHidden: Bool {
        guard let until = temporarilyHiddenUntil else { return false }
        if Date() < until { return true }
        temporarilyHiddenUntil = nil
        return false
    }

    private func lineWidth(for settings: AppSettings) -> CGFloat {
        switch settings.borderWeight {
        case .thin: return 2
        case .regular: return 4
        case .bold: return 6
        case .custom: return CGFloat(settings.borderCustomWidth)
        }
    }
}
