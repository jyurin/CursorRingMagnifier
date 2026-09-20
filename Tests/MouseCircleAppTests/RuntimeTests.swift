import AppKit
import CoreMedia
import Testing
@testable import MouseCircleApp

@Suite @MainActor
struct RuntimeTests {
    @Test func burstMotionOnlyKeepsNewestPositionAndStopsWhenIdle() async throws {
        let coalescer = FrameCoalescer<Int>(framesPerSecond: 60)
        var values: [Int] = []
        coalescer.deliver = { values.append($0) }
        for i in 0..<10_000 { coalescer.submit(i) }
        try await Task.sleep(for: .milliseconds(80))
        #expect(values == [0, 9_999])
        try await Task.sleep(for: .milliseconds(80))
        #expect(values.count == 2)
    }

    @Test func disablingPointerCancelsPendingWork() async throws {
        let coalescer = FrameCoalescer<Int>(framesPerSecond: 30)
        var values: [Int] = []
        coalescer.deliver = { values.append($0) }
        coalescer.submit(1)
        coalescer.submit(2)
        coalescer.cancel()
        try await Task.sleep(for: .milliseconds(80))
        #expect(values == [1])
        coalescer.submit(2)
        #expect(values == [1, 2])
    }

    @Test func ringAppearanceIsNotRedrawnForIdenticalState() {
        let view = RingOverlayView(frame: CGRect(x: 0, y: 0, width: 98, height: 98))
        var settings = AppSettings()
        for _ in 0..<1000 { view.update(settings: settings, clicks: ClickState()) }
        #expect(view.appearanceUpdateCount == 1)
        settings.magnifierScale = .x300
        view.update(settings: settings, clicks: ClickState())
        #expect(view.appearanceUpdateCount == 1)
        view.update(settings: settings, clicks: ClickState(left: true))
        #expect(view.appearanceUpdateCount == 2)
        view.update(settings: settings, clicks: ClickState())
        #expect(view.appearanceUpdateCount == 3)
    }

    @Test func streamIsBoundedAndDoesNotCaptureAudioOrCursor() {
        let config = ScreenCaptureBackend.configuration(request())
        #expect(config.width == 980 && config.height == 544)
        #expect(config.queueDepth == 3)
        #expect(config.minimumFrameInterval == CMTime(value: 1, timescale: 30))
        #expect(!config.capturesAudio && !config.showsCursor)
        #expect(config.sourceRect.width == 490)
    }

    @Test func releaseDuringStartupCannotResurrectLens() async throws {
        let backend = FakeCaptureBackend()
        backend.pauseStart = true
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        try await waitFor { backend.startContinuation != nil }
        let session = try #require(backend.sessions.first)
        coordinator.setRequest(nil)
        #expect(!coordinator.accepts(session))
        backend.finishStart()
        await coordinator.waitUntilSettled()
        #expect(backend.starts.count == 1 && backend.stops == 1)
        #expect(backend.liveStreams == 0)
    }

    @Test func rapidReleaseAndRepressSerializeStreams() async throws {
        let backend = FakeCaptureBackend()
        backend.pauseStart = true
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        try await waitFor { backend.startContinuation != nil }
        coordinator.setRequest(nil)
        coordinator.setRequest(request(x: 80))
        backend.finishStart()
        await coordinator.waitUntilSettled()
        #expect(backend.starts.map(\.sourceRect.minX) == [0, 80])
        #expect(backend.stops == 1 && backend.maximumLiveStreams == 1)
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
        #expect(backend.liveStreams == 0)
    }

    @Test func slowCaptureUpdatesCoalesceInsteadOfBacklogging() async throws {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        backend.pauseUpdate = true
        coordinator.setRequest(request(x: 1))
        try await waitFor { backend.updateContinuation != nil }
        for x in 2...1000 { coordinator.setRequest(request(x: CGFloat(x))) }
        backend.finishUpdate()
        await coordinator.waitUntilSettled()
        #expect(backend.updates.map(\.sourceRect.minX) == [1, 1000])
        #expect(backend.starts.count == 1)
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
    }

    @Test func displaySwitchRestartsAndRejectsOldFrames() async throws {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        let old = try #require(backend.sessions.last)
        coordinator.setRequest(request(display: 2))
        #expect(!coordinator.accepts(old))
        await coordinator.waitUntilSettled()
        #expect(backend.starts.map(\.displayID) == [1, 2])
        #expect(backend.stops == 1 && backend.maximumLiveStreams == 1)
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
    }

    @Test func failureCleansUpAndAllowsRetry() async {
        let backend = FakeCaptureBackend()
        backend.failStart = true
        let coordinator = CaptureCoordinator(backend: backend)
        var errors: [String] = []
        coordinator.onFailure = { errors.append($0) }
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        #expect(errors.count == 1 && backend.liveStreams == 0)
        backend.failStart = false
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        #expect(backend.starts.count == 2 && backend.liveStreams == 1)
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
    }

    @Test func sameRequestDoesNotRestartCapture() async {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        for _ in 0..<1000 { coordinator.setRequest(request()) }
        await coordinator.waitUntilSettled()
        #expect(backend.starts.count == 1 && backend.updates.isEmpty && backend.stops == 0)
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
    }

    @Test func releaseDuringConfigurationUpdateStopsStream() async throws {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        backend.pauseUpdate = true
        coordinator.setRequest(request(x: 1))
        try await waitFor { backend.updateContinuation != nil }
        let session = try #require(backend.sessions.last)
        coordinator.setRequest(nil)
        #expect(!coordinator.accepts(session))
        backend.finishUpdate()
        await coordinator.waitUntilSettled()
        #expect(backend.liveStreams == 0 && backend.stops == 1)
    }

    @Test func unexpectedStreamFailureStopsAndRejectsLateFrames() async throws {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        var errors = 0
        coordinator.onFailure = { _ in errors += 1 }
        coordinator.setRequest(request())
        await coordinator.waitUntilSettled()
        let session = try #require(backend.sessions.last)
        coordinator.failed(session: session, message: "Disconnected")
        #expect(!coordinator.accepts(session))
        await coordinator.waitUntilSettled()
        #expect(backend.liveStreams == 0 && errors == 1)
        coordinator.failed(session: session, message: "Late callback")
        #expect(errors == 1)
    }

    @Test func noStreamIsStartedIfReleasedBeforeWorkerRuns() async {
        let backend = FakeCaptureBackend()
        let coordinator = CaptureCoordinator(backend: backend)
        coordinator.setRequest(request())
        coordinator.setRequest(nil)
        await coordinator.waitUntilSettled()
        #expect(backend.starts.isEmpty && backend.stops == 0)
    }

    @Test func screenshotSelectionStaysHiddenUntilFinished() async throws {
        let guarder = ScreenshotGuard()
        guarder.modifiersChanged([.command, .shift])
        #expect(guarder.isHidden)
        guarder.keyDown(21, flags: [.command, .shift])
        guarder.modifiersChanged([])
        try await Task.sleep(for: .seconds(2))
        #expect(guarder.isHidden)
        guarder.mouseUp()
        try await Task.sleep(for: .milliseconds(750))
        #expect(!guarder.isHidden)
    }

    @Test func toolbarDoesNotReappearOnOptionsClick() async throws {
        let guarder = ScreenshotGuard()
        guarder.modifiersChanged([.command, .shift])
        guarder.keyDown(23, flags: [.command, .shift])
        guarder.modifiersChanged([])
        guarder.mouseUp()
        #expect(guarder.isHidden)
        guarder.screenshotApplicationEnded()
        try await Task.sleep(for: .milliseconds(750))
        #expect(!guarder.isHidden)
    }

    @Test func otherCommandShiftShortcutsRestoreOnRelease() {
        let guarder = ScreenshotGuard()
        guarder.modifiersChanged([.command, .shift])
        guarder.keyDown(46, flags: [.command, .shift])
        guarder.modifiersChanged([])
        #expect(!guarder.isHidden)
    }

    private func request(x: CGFloat = 0, display: UInt32 = 1) -> CaptureRequest {
        CaptureRequest(displayID: display, sourceRect: CGRect(x: x, y: 0, width: 490, height: 272),
                       pixelWidth: 980, pixelHeight: 544, excludedWindowIDs: [10, 11], contentRevision: 0)
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Timed out waiting for the capture worker")
        throw TestFailure.timeout
    }
}

private enum TestFailure: Error { case start, timeout }

@MainActor
private final class FakeCaptureBackend: CaptureBackend {
    var starts: [CaptureRequest] = []
    var updates: [CaptureRequest] = []
    var sessions: [UUID] = []
    var stops = 0
    var liveStreams = 0
    var maximumLiveStreams = 0
    var pauseStart = false
    var pauseUpdate = false
    var failStart = false
    var startContinuation: CheckedContinuation<Void, Never>?
    var updateContinuation: CheckedContinuation<Void, Never>?

    func start(_ request: CaptureRequest, session: UUID) async throws {
        starts.append(request)
        sessions.append(session)
        liveStreams += 1
        maximumLiveStreams = max(maximumLiveStreams, liveStreams)
        if pauseStart { await withCheckedContinuation { startContinuation = $0 } }
        if failStart { throw TestFailure.start }
    }

    func update(_ request: CaptureRequest) async throws {
        updates.append(request)
        if pauseUpdate { await withCheckedContinuation { updateContinuation = $0 } }
    }

    func stop() async { stops += 1; liveStreams = max(0, liveStreams - 1) }
    func discardFrames() {}
    func finishStart() { pauseStart = false; startContinuation?.resume(); startContinuation = nil }
    func finishUpdate() { pauseUpdate = false; updateContinuation?.resume(); updateContinuation = nil }
}
