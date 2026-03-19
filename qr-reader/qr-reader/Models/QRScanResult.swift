import Foundation

struct QRScanResult: Identifiable, Hashable, Codable {
    let id: UUID
    let payload: String
    let symbology: String
    let scannedAt: Date

    init(
        id: UUID = UUID(),
        payload: String,
        symbology: String = "QR",
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.payload = payload
        self.symbology = symbology
        self.scannedAt = scannedAt
    }
}
