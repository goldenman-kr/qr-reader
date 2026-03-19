import Combine
import Foundation

@MainActor
final class ScanResultsStore: ObservableObject {
    @Published private(set) var items: [QRScanResult] = []
    @Published private(set) var scannedAt: Date?

    func update(with results: [QRScanResult]) {
        items = results
        scannedAt = Date()
    }

    func clear() {
        items = []
        scannedAt = nil
    }
}
