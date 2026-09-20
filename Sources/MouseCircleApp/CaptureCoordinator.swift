import CoreGraphics
import Foundation

struct CaptureRequest: Equatable {
    let displayID: CGDirectDisplayID
    let sourceRect: CGRect
    let pixelWidth: Int
    let pixelHeight: Int
    let excludedWindowIDs: Set<CGWindowID>
    let contentRevision: Int

    func usesSameSource(as other: Self) -> Bool {
        displayID == other.displayID && excludedWindowIDs == other.excludedWindowIDs && contentRevision == other.contentRevision
    }
}

@MainActor
protocol CaptureBackend: AnyObject {
    func start(_ request: CaptureRequest, session: UUID) async throws
    func update(_ request: CaptureRequest) async throws
    func discardFrames()
    func stop() async
}

// One serialized worker owns capture. New requests replace pending work instead of queuing it.
@MainActor
final class CaptureCoordinator {
    var onFailure: ((String) -> Void)?
    private struct Target {
        var request: CaptureRequest
        let session: UUID
    }
    private let backend: any CaptureBackend
    private var desired: Target?
    private var active: Target?
    private var worker: Task<Void, Never>?

    init(backend: any CaptureBackend) { self.backend = backend }

    func setRequest(_ request: CaptureRequest?) {
        if let request {
            if let current = desired, current.request.usesSameSource(as: request) {
                desired?.request = request
            } else {
                backend.discardFrames()
                desired = Target(request: request, session: UUID())
            }
        } else {
            desired = nil
            backend.discardFrames()
        }
        scheduleWorker()
    }

    func accepts(_ session: UUID) -> Bool { desired?.session == session }

    func failed(session: UUID, message: String) {
        guard accepts(session) else { return }
        setRequest(nil)
        onFailure?(message)
    }

    func waitUntilSettled() async { await worker?.value }

    private func scheduleWorker() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.reconcile()
            self?.worker = nil
        }
    }

    private func reconcile() async {
        while true {
            if let active, active.session != desired?.session {
                self.active = nil
                await backend.stop()
                continue
            }
            guard let next = desired else { return }
            do {
                if active == nil {
                    try await backend.start(next.request, session: next.session)
                    active = next
                } else if active?.request != next.request {
                    try await backend.update(next.request)
                    active = next
                } else {
                    return
                }
            } catch {
                active = nil
                await backend.stop()
                // A late error from an old display/hold must not cancel a newer request.
                if accepts(next.session) {
                    desired = nil
                    onFailure?(error.localizedDescription)
                }
            }
        }
    }
}
