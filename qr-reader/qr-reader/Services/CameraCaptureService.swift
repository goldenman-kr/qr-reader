import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct CameraDeviceInfo: Identifiable, Hashable {
    let id: String
    let name: String
}

enum CameraCaptureError: Error {
    case permissionDenied
    case deviceUnavailable
    case frameUnavailable
}

final class CameraCaptureService: NSObject {
    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.capture.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.capture.output.queue")
    private let ciContext = CIContext()
    private let lock = NSLock()
    private let desiredRequestLock = NSLock()
    private var latestBuffer: CMSampleBuffer?
    private var desiredCameraRequestID: Int?

    override init() {
        super.init()
        configureOutput()
    }

    static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func discoverDevices() -> [CameraDeviceInfo] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { device in
            CameraDeviceInfo(id: device.uniqueID, name: device.localizedName)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setDesiredCameraRequest(_ requestID: Int?) {
        desiredRequestLock.lock()
        desiredCameraRequestID = requestID
        desiredRequestLock.unlock()
    }

    func start(deviceID: String?, requestID: Int) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard isDesiredCameraRequest(requestID) else {
                        throw CancellationError()
                    }
                    guard Self.authorizationStatus() == .authorized else {
                        throw CameraCaptureError.permissionDenied
                    }

                    let discovery = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                        mediaType: .video,
                        position: .unspecified
                    )
                    let devices = discovery.devices
                    let chosenDevice: AVCaptureDevice?
                    if let deviceID {
                        chosenDevice = devices.first(where: { $0.uniqueID == deviceID })
                    } else {
                        chosenDevice = devices.first
                    }
                    guard let device = chosenDevice else {
                        throw CameraCaptureError.deviceUnavailable
                    }

                    let input = try AVCaptureDeviceInput(device: device)
                    session.beginConfiguration()
                    session.sessionPreset = .medium
                    session.inputs.forEach { session.removeInput($0) }
                    if session.canAddInput(input) {
                        session.addInput(input)
                    }
                    if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
                        session.addOutput(videoOutput)
                    }
                    session.commitConfiguration()

                    limitFrameRate(of: device, to: 15)
                    guard isDesiredCameraRequest(requestID) else {
                        clearLatestBuffer()
                        throw CancellationError()
                    }
                    if !session.isRunning {
                        session.startRunning()
                    }
                    guard isDesiredCameraRequest(requestID) else {
                        session.stopRunning()
                        clearLatestBuffer()
                        throw CancellationError()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stopIfInactive() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                if !hasDesiredCameraRequest() {
                    if session.isRunning {
                        session.stopRunning()
                    }
                    clearLatestBuffer()
                }
                continuation.resume()
            }
        }
    }

    func captureCurrentFrame() throws -> CGImage {
        lock.lock()
        let sample = latestBuffer
        lock.unlock()

        guard
            let sample,
            let buffer = CMSampleBufferGetImageBuffer(sample)
        else {
            throw CameraCaptureError.frameUnavailable
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CameraCaptureError.frameUnavailable
        }
        return cgImage
    }

    private func configureOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }

    private func limitFrameRate(of device: AVCaptureDevice, to framesPerSecond: Double) {
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= framesPerSecond && framesPerSecond <= $0.maxFrameRate
        }) else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let duration = CMTime(seconds: 1 / framesPerSecond, preferredTimescale: 600)
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } catch {
            // Keep the device default if its frame rate cannot be configured.
        }
    }

    private func isDesiredCameraRequest(_ requestID: Int) -> Bool {
        desiredRequestLock.lock()
        defer { desiredRequestLock.unlock() }
        return desiredCameraRequestID == requestID
    }

    private func hasDesiredCameraRequest() -> Bool {
        desiredRequestLock.lock()
        defer { desiredRequestLock.unlock() }
        return desiredCameraRequestID != nil
    }

    private func clearLatestBuffer() {
        lock.lock()
        latestBuffer = nil
        lock.unlock()
    }
}

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        lock.lock()
        latestBuffer = sampleBuffer
        lock.unlock()
    }
}
