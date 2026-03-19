import Combine
import Foundation

final class UserDefaultsHistoryStore: ObservableObject, HistoryStore {
    @Published private(set) var items: [ScanHistoryItem] = []
    var maxCount: Int = 100

    private let key = "scan_history_items_v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    func reload() {
        guard let data = defaults.data(forKey: key) else {
            items = []
            return
        }

        do {
            items = try decoder.decode([ScanHistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    func append(_ item: ScanHistoryItem) {
        items.insert(item, at: 0)
        if items.count > maxCount {
            items = Array(items.prefix(maxCount))
        }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(items)
            defaults.set(data, forKey: key)
        } catch {
            print("History persist error: \(error)")
        }
    }
}
