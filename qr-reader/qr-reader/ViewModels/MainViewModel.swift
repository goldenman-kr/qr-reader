import AppKit
import AVFoundation
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
    @Published private(set) var availableCameras: [CameraDeviceInfo] = []
    @Published private(set) var cameraAccessDenied: Bool = false

    private let historyStore: HistoryStore
    private let oneShotCaptureService = OneShotScreenCaptureService()
    private let cameraCaptureService = CameraCaptureService()
    private let qrDetector = VisionQRDetector()
    private var cameraRequestID = 0

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
        refreshCameraDevices()
    }

    func captureAndScan() {
        switch selectedSource {
        case .screen:
            captureAndScanFromScreen()
        case .camera:
            captureAndScanFromCamera()
        }
    }

    func selectSource(_ source: CaptureSource) {
        cameraRequestID += 1
        let requestID = cameraRequestID
        selectedSource = source
        switch source {
        case .screen:
            cameraCaptureService.setDesiredCameraRequest(nil)
            cameraAccessDenied = false
            statusMessage = "Screen mode."
            Task {
                await cameraCaptureService.stopIfInactive()
            }
        case .camera(let deviceID):
            if let deviceID { UserDefaults.standard.set(deviceID, forKey: "lastCameraDeviceID") }
            cameraCaptureService.setDesiredCameraRequest(requestID)
            activateCameraSource(deviceID: deviceID, requestID: requestID)
        }
    }

    func refreshCameraDevices() {
        let devices = cameraCaptureService.discoverDevices()
        if devices != availableCameras { availableCameras = devices }
    }

    /// Returns true when the user needs to choose a device in the popover.
    func selectCameraMode() -> Bool {
        refreshCameraDevices()
        if case .camera = selectedSource { return true }
        let lastID = UserDefaults.standard.string(forKey: "lastCameraDeviceID")
        if let camera = availableCameras.first(where: { $0.id == lastID }) {
            selectSource(.camera(deviceID: camera.id))
            return false
        }
        if availableCameras.count == 1, let camera = availableCameras.first {
            selectSource(.camera(deviceID: camera.id))
            return false
        }
        return true
    }

    var sourceOptions: [(source: CaptureSource, title: String)] {
        let cameraOptions = availableCameras.map { camera in
            (source: CaptureSource.camera(deviceID: camera.id), title: camera.name)
        }
        return [(source: .screen, title: "Screen")] + cameraOptions
    }

    var selectedSourceTitle: String {
        switch selectedSource {
        case .screen:
            return "Screen"
        case .camera(let deviceID):
            if let deviceID, let match = availableCameras.first(where: { $0.id == deviceID }) {
                return match.name
            }
            return "Camera"
        }
    }

    var shouldShowCameraPreview: Bool {
        if case .camera = selectedSource {
            return !cameraAccessDenied
        }
        return false
    }

    var cameraSession: AVCaptureSession {
        cameraCaptureService.session
    }

    private func captureAndScanFromScreen() {
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

    private func captureAndScanFromCamera() {
        statusMessage = "Capturing camera frame..."
        Task {
            do {
                let image = try cameraCaptureService.captureCurrentFrame()
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
            } catch CameraCaptureError.frameUnavailable {
                await MainActor.run {
                    self.statusMessage = "Camera frame unavailable."
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Capture/scan failed."
                }
            }
        }
    }

    private func activateCameraSource(deviceID: String?, requestID: Int) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            Task {
                await startCamera(deviceID: deviceID, requestID: requestID)
            }
        case .notDetermined:
            Task {
                let granted = await CameraCaptureService.requestAccess()
                guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
                if granted {
                    cameraAccessDenied = false
                    await startCamera(deviceID: deviceID, requestID: requestID)
                } else {
                    fallBackToScreen(message: "Camera permission denied.", accessDenied: true)
                }
            }
        default:
            fallBackToScreen(message: "Camera permission denied.", accessDenied: true)
        }
    }

    private func startCamera(deviceID: String?, requestID: Int) async {
        guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
        refreshCameraDevices()
        do {
            try await cameraCaptureService.start(deviceID: deviceID, requestID: requestID)
            guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
            cameraAccessDenied = false
            if case .camera(let id) = selectedSource, id == nil, let first = availableCameras.first {
                selectedSource = .camera(deviceID: first.id)
            }
            statusMessage = "Camera mode."
        } catch is CancellationError {
            return
        } catch CameraCaptureError.deviceUnavailable {
            guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
            fallBackToScreen(message: "No camera available.")
        } catch CameraCaptureError.permissionDenied {
            guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
            fallBackToScreen(message: "Camera permission denied.", accessDenied: true)
        } catch {
            guard isCurrentCameraRequest(requestID, deviceID: deviceID) else { return }
            fallBackToScreen(message: "Failed to start camera.")
        }
    }

    func pauseCamera() {
        cameraRequestID += 1
        cameraCaptureService.setDesiredCameraRequest(nil)
        Task {
            await cameraCaptureService.stopIfInactive()
        }
    }

    func resumeCameraIfNeeded() {
        guard case .camera(let deviceID) = selectedSource else { return }
        cameraRequestID += 1
        cameraCaptureService.setDesiredCameraRequest(cameraRequestID)
        activateCameraSource(deviceID: deviceID, requestID: cameraRequestID)
    }

    private func isCurrentCameraRequest(_ requestID: Int, deviceID: String?) -> Bool {
        guard requestID == cameraRequestID else { return false }
        return selectedSource == .camera(deviceID: deviceID)
    }

    private func fallBackToScreen(message: String, accessDenied: Bool = false) {
        selectedSource = .screen
        cameraAccessDenied = accessDenied
        statusMessage = message
        cameraCaptureService.setDesiredCameraRequest(nil)
        Task {
            await cameraCaptureService.stopIfInactive()
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
        guard windowFrameInScreen != standardized else { return }
        windowFrameInScreen = standardized
    }

    func updateWindowContentRectInScreen(_ rect: CGRect) {
        let standardized = rect.standardized
        guard standardized.width > 0, standardized.height > 0 else { return }
        guard windowContentRectInScreen != standardized else { return }
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
