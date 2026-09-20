import AppKit

@MainActor
final class InputMonitors {
    var onCursorMoved: ((CGPoint) -> Void)?
    var onClickStateChanged: ((Bool, Bool) -> Void)?
    var onModifierFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?
    var onKeyDown: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    private var monitors: [Any] = []
    private var movementMonitors: [Any] = []
    private let cursor = FrameCoalescer<CGPoint>(framesPerSecond: 60)
    private var running = false
    private var tracking = false

    func start() {
        guard !running else { return }
        running = true
        cursor.deliver = { [weak self] in self?.onCursorMoved?($0) }
        monitors = observe([.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown, .flagsChanged]) {
            [weak self] event in self?.handle(event)
        }
    }

    func setPointerTracking(_ enabled: Bool) {
        guard enabled != tracking else { return }
        tracking = enabled
        movementMonitors.forEach(NSEvent.removeMonitor)
        movementMonitors.removeAll()
        cursor.cancel()
        if enabled && running {
            movementMonitors = observe([.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) {
                [weak self] _ in self?.cursor.submit(NSEvent.mouseLocation)
            }
            onCursorMoved?(NSEvent.mouseLocation)
        }
    }

    func stop() {
        setPointerTracking(false)
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        running = false
    }

    private func observe(_ mask: NSEvent.EventTypeMask, handler: @escaping @MainActor (NSEvent) -> Void) -> [Any] {
        var tokens: [Any] = []
        // AppKit documents both event-monitor callbacks as main-thread callbacks.
        if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { handler(event) }
        }) { tokens.append(token) }
        if let token = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { handler(event) }
            return event
        }) { tokens.append(token) }
        return tokens
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            onModifierFlagsChanged?(event.modifierFlags)
        case .keyDown:
            if !event.isARepeat { onKeyDown?(event.keyCode, event.modifierFlags) }
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            if tracking {
                cursor.cancel()
                onCursorMoved?(NSEvent.mouseLocation)
            }
            onClickStateChanged?(event.type == .leftMouseDown || event.type == .rightMouseDown,
                                 event.type == .rightMouseDown || event.type == .rightMouseUp)
        default: break
        }
    }
}
