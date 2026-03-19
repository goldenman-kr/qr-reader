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
    private let outputQueue = DispatchQueue(label: "camera.capture.output.queue")
    private let ciContext = CIContext()
    private let lock = NSLock()
    private var latestBuffer: CMSampleBuffer?

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

    func start(deviceID: String?) throws {
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
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        session.inputs.forEach { session.removeInput($0) }
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if !session.outputs.contains(videoOutput), session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if !session.isRunning {
            outputQueue.async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    func stop() {
        guard session.isRunning else { return }
        outputQueue.async { [weak self] in
            self?.session.stopRunning()
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
