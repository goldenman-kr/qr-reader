import Foundation

struct ScanHistoryItem: Identifiable, Hashable, Codable {
    let id: UUID
    let source: CaptureSource
    let createdAt: Date
    let results: [QRScanResult]

    init(
        id: UUID = UUID(),
        source: CaptureSource,
        createdAt: Date = Date(),
        results: [QRScanResult]
    ) {
        self.id = id
        self.source = source
        self.createdAt = createdAt
        self.results = results
    }
}
