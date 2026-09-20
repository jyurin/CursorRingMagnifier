import AppKit

@MainActor
final class ScreenshotGuard {
    var onChange: ((Bool) -> Void)?
    private(set) var isHidden = false
    private var modifiersPrimed = false
    private var selectionActive = false
    private var toolbarActive = false
    private var restore: DispatchWorkItem?

    func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        modifiersPrimed = flags.contains([.command, .shift])
        update()
    }

    func keyDown(_ key: UInt16, flags: NSEvent.ModifierFlags) {
        if key == 53 { finish(after: 0.25); return } // Escape cancels region/window/toolbar capture.
        if key == 36, selectionActive || toolbarActive { finish(after: 1); return }
        guard flags.contains([.command, .shift]), [18, 19, 20, 21, 23, 22].contains(key) else { return }
        restore?.cancel()
        restore = nil
        selectionActive = key == 21 // Command-Shift-4: keep hidden for the whole selection.
        toolbarActive = key == 23 // Command-Shift-5: wait for Screenshot UI to close.
        if !selectionActive && !toolbarActive { finish(after: 1.8) }
        update()
    }

    func mouseUp() {
        if selectionActive { finish(after: 0.6) }
    }

    func screenshotApplicationEnded() {
        if toolbarActive || selectionActive { finish(after: 0.6) }
    }

    func reset() {
        restore?.cancel()
        restore = nil
        modifiersPrimed = false
        selectionActive = false
        toolbarActive = false
        update()
    }

    private func finish(after delay: TimeInterval) {
        guard modifiersPrimed || isHidden || selectionActive || toolbarActive else { return }
        restore?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.restore = nil
            self.selectionActive = false
            self.toolbarActive = false
            self.update()
        }
        restore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        update()
    }

    private func update() {
        let hidden = modifiersPrimed || selectionActive || toolbarActive || restore != nil
        guard hidden != isHidden else { return }
        isHidden = hidden
        onChange?(hidden)
    }
}
