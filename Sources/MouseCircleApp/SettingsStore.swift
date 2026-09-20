import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let defaultsKey = "mouse_circle.settings.v1"
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            dirty = true
            saveWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.flush() }
            saveWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    private let defaults: UserDefaults
    private var dirty = false
    private var saveWork: DispatchWorkItem?
    private(set) var saveCount = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    func flush() {
        saveWork?.cancel()
        saveWork = nil
        guard dirty, let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
        dirty = false
        saveCount += 1
    }
}
