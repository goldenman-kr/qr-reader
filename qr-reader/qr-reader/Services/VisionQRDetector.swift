import CoreGraphics
import Foundation
import Vision

final class VisionQRDetector {
    func detect(in image: CGImage) throws -> [QRScanResult] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.QR]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results as? [VNBarcodeObservation] ?? []
        let payloads = observations.compactMap { $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let unique = Array(NSOrderedSet(array: payloads)) as? [String] ?? []
        return unique.map { QRScanResult(payload: $0, symbology: "QR") }
    }
}
