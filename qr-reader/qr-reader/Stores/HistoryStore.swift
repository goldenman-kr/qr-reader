import Foundation

protocol HistoryStore: AnyObject {
    var items: [ScanHistoryItem] { get }
    var maxCount: Int { get set }

    func reload()
    func append(_ item: ScanHistoryItem)
    func clear()
}
