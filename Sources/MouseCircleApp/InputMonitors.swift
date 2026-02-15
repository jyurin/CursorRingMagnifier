import AppKit
import Foundation

@MainActor
final class InputMonitors {
    var onCursorMoved: ((CGPoint) -> Void)?
    var onClickStateChanged: ((Bool, Bool) -> Void)?
    var onModifierFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?
    var onKeyDown: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    private var cursorTimer: Timer?

    func start() {
        stop()

        globalMonitors.append(
            NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handleClick(event)
                }
            } as Any
        )

        globalMonitors.append(
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                Task { @MainActor in
                    self?.handleHotkey(event)
                }
            } as Any
        )

        localMonitors.append(
            NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                self?.handleHotkey(event)
                return event
            } as Any
        )

        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.onCursorMoved?(NSEvent.mouseLocation)
            }
        }
    }

    func stop() {
        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        for monitor in localMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
        localMonitors.removeAll()

        cursorTimer?.invalidate()
        cursorTimer = nil
    }

    private func handleHotkey(_ event: NSEvent) {
        if event.type == .flagsChanged {
            onModifierFlagsChanged?(event.modifierFlags)
            return
        }

        guard event.type == .keyDown else { return }
        onKeyDown?(event.keyCode, event.modifierFlags)
    }

    private func handleClick(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            onClickStateChanged?(true, false)
        case .leftMouseUp:
            onClickStateChanged?(false, false)
        case .rightMouseDown:
            onClickStateChanged?(true, true)
        case .rightMouseUp:
            onClickStateChanged?(false, true)
        default:
            break
        }
    }
}
