import AppKit
import Combine
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var selectedSource: CaptureSource = .screen
    @Published var latestResults: [QRScanResult] = []
    @Published var statusMessage: String = "Ready"
    @Published var screenPermissionState: ScreenCapturePermissionState = .unknown
    @Published var viewfinderRectInScreen: CGRect = .zero
    @Published var windowContentRectInScreen: CGRect = .zero
    @Published var windowFrameInScreen: CGRect = .zero
    @Published var debugCapturedImage: CGImage?
    @Published var debugCaptureRect: CGRect = .zero
    @Published var debugBackingScaleFactor: CGFloat = 0
    @Published var debugCaptureDisplayHeight: Int = 0
    @Published var debugWindowFrameInScreen: CGRect = .zero
    @Published var debugCaptureVersion: Int = 0

    private let historyStore: HistoryStore
    private let oneShotCaptureService = OneShotScreenCaptureService()
    private let qrDetector = VisionQRDetector()

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func captureAndScan() {
        guard selectedSource == .screen else {
            statusMessage = "Camera source is not implemented yet."
            return
        }
        guard !windowContentRectInScreen.isEmpty else {
            statusMessage = "Window content rect not ready."
            return
        }

        let localHole = PhoneLayout.viewfinderRect(in: PhoneLayout.phoneSize)
        let captureRect = Self.captureRectInScreen(
            windowContentRectInScreen: windowContentRectInScreen,
            localHoleRect: localHole
        )
        guard !captureRect.isEmpty else {
            statusMessage = "Capture rect invalid."
            return
        }

        statusMessage = "Capturing..."

        Task {
            #if DEBUG
            await MainActor.run {
                self.viewfinderRectInScreen = captureRect
                print("[CaptureDebug] viewfinderRectInScreen=\(self.viewfinderRectInScreen)")
                print("[CaptureDebug] windowContentRectInScreen=\(self.windowContentRectInScreen)")
                print("[CaptureDebug] finalCaptureRectInScreen=\(captureRect)")
                let scale = NSApp.mainWindow?.backingScaleFactor ?? 0
                let displayHeight = NSScreen.screens.first(where: { $0.frame.contains(captureRect.center) })?.frame.height ?? 0
                let topY = max(0, displayHeight - captureRect.maxY)
                print("[CaptureDebug] captureY(bottom-origin)=\(String(format: "%.1f", captureRect.minY)) top-from-display=\(String(format: "%.1f", topY))")
                print("[CaptureDebug] backingScaleFactor=\(String(format: "%.3f", scale)) displayHeight=\(String(format: "%.1f", displayHeight))")
                CaptureDebugOverlay.shared.flash(rects: [
                    .init(rect: self.viewfinderRectInScreen, color: .systemGreen),
                    .init(rect: captureRect, color: .systemRed)
                ])
            }
            #endif
            do {
                let output = try await oneShotCaptureService.capture(rectInScreenPoints: captureRect)
                let image = output.image
                await MainActor.run {
                    if Self.isCaptureDebugEnabled {
                        self.debugCapturedImage = image
                        self.debugCaptureRect = captureRect
                        self.debugBackingScaleFactor = NSApp.mainWindow?.backingScaleFactor ?? 0
                        self.debugCaptureDisplayHeight = output.displayHeightPixels
                        self.debugWindowFrameInScreen = self.windowFrameInScreen
                        self.debugCaptureVersion += 1
                    }
                }
                let results = try qrDetector.detect(in: image)
                await MainActor.run {
                    self.latestResults = results
                    if results.isEmpty {
                        self.statusMessage = "No QR code found."
                    } else {
                        let historyItem = ScanHistoryItem(source: self.selectedSource, results: results)
                        self.historyStore.append(historyItem)
                        self.statusMessage = "Detected \(results.count) QR code(s)"
                    }
                }
            } catch OneShotCaptureError.permissionDenied {
                await MainActor.run {
                    self.screenPermissionState = .denied
                    self.statusMessage = "Screen Recording permission denied."
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Capture/scan failed."
                }
            }
        }
    }

    func copyPayload(_ payload: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
    }

    func refreshScreenPermission() {
        if OneShotScreenCaptureService.preflightAccess() {
            screenPermissionState = .granted
        } else {
            screenPermissionState = .unknown
        }
    }

    func requestScreenPermission() {
        let granted = OneShotScreenCaptureService.requestAccess()
        screenPermissionState = granted ? .granted : .denied
    }

    func updateWindowFrameInScreen(_ rect: CGRect) {
        let standardized = rect.standardized
        guard standardized.width > 0, standardized.height > 0 else { return }
        windowFrameInScreen = standardized
    }

    func updateWindowContentRectInScreen(_ rect: CGRect) {
        let standardized = rect.standardized
        guard standardized.width > 0, standardized.height > 0 else { return }
        windowContentRectInScreen = standardized
    }

    private static var isCaptureDebugEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "captureDebugEnabled") == nil {
            return true
        }
        return defaults.bool(forKey: "captureDebugEnabled")
    }

    private static func captureRectInScreen(windowContentRectInScreen: CGRect, localHoleRect: CGRect) -> CGRect {
        // localHoleRect uses top-left origin in SwiftUI content space.
        // screen rect uses bottom-left origin.
        let x = windowContentRectInScreen.minX + localHoleRect.minX
        let y = windowContentRectInScreen.maxY - localHoleRect.maxY
        return CGRect(x: x, y: y, width: localHoleRect.width, height: localHoleRect.height).standardized
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
