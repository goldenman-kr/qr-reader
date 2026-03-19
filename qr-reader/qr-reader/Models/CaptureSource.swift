import Foundation

enum CaptureSource: Hashable, Codable, Identifiable {
    case screen
    case camera(deviceID: String?)

    var id: String {
        switch self {
        case .screen:
            return "screen"
        case .camera(let deviceID):
            return "camera:\(deviceID ?? "default")"
        }
    }

    var displayName: String {
        switch self {
        case .screen:
            return "Screen"
        case .camera:
            return "Camera"
        }
    }
}
