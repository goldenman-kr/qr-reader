import CoreGraphics
import ImageIO
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

enum OneShotCaptureError: Error {
    case permissionDenied
    case noDisplayFound
    case invalidRect
}

struct OneShotCaptureOutput {
    let image: CGImage
    let displayHeightPixels: Int
}

final class OneShotScreenCaptureService {
    static func preflightAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func capture(rectInScreenPoints: CGRect) async throws -> OneShotCaptureOutput {
        let requestedRect = rectInScreenPoints.standardized
        guard !requestedRect.isEmpty else {
            throw OneShotCaptureError.invalidRect
        }

        guard Self.preflightAccess() || Self.requestAccess() else {
            throw OneShotCaptureError.permissionDenied
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = Self.displayContaining(rect: requestedRect, from: shareableContent.displays) else {
            throw OneShotCaptureError.noDisplayFound
        }

        let sourceRect = Self.clampedSourceRect(for: requestedRect, in: display.frame)
        guard sourceRect.width > 2, sourceRect.height > 2 else {
            throw OneShotCaptureError.invalidRect
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect

        let scaleX = CGFloat(display.width) / display.frame.width
        let scaleY = CGFloat(display.height) / display.frame.height
        configuration.width = max(1, Int(sourceRect.width * scaleX))
        configuration.height = max(1, Int(sourceRect.height * scaleY))
        configuration.showsCursor = false

        #if DEBUG
        print("[CaptureDebug] requestedRect(screen-pt)=\(Self.pretty(requestedRect))")
        print("[CaptureDebug] display.frame(screen-pt)=\(Self.pretty(display.frame))")
        print("[CaptureDebug] display.height(px)=\(display.height)")
        let rawIntersection = requestedRect.intersection(display.frame)
        let yBottomOrigin = rawIntersection.origin.y - display.frame.origin.y
        let yTopOrigin = display.frame.maxY - rawIntersection.maxY
        print("[CaptureDebug-Y] intersection(screen-pt)=\(Self.pretty(rawIntersection))")
        print("[CaptureDebug-Y] sourceY(bottom-origin-candidate)=\(String(format: "%.2f", yBottomOrigin)) sourceY(top-origin-candidate)=\(String(format: "%.2f", yTopOrigin))")
        print("[CaptureDebug] sourceRect(display-pt)=\(Self.pretty(sourceRect))")
        print("[CaptureDebug] outputSize(px)=\(configuration.width)x\(configuration.height), scale=\(String(format: "%.3f", scaleX))/\(String(format: "%.3f", scaleY))")
        #endif

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        #if DEBUG
        Self.saveDebugImage(image)
        #endif
        return OneShotCaptureOutput(image: image, displayHeightPixels: display.height)
    }

    private static func displayContaining(rect: CGRect, from displays: [SCDisplay]) -> SCDisplay? {
        let midPoint = CGPoint(x: rect.midX, y: rect.midY)
        if let containing = displays.first(where: { $0.frame.contains(midPoint) }) {
            return containing
        }

        return displays.max { lhs, rhs in
            let leftArea = lhs.frame.intersection(rect).area
            let rightArea = rhs.frame.intersection(rect).area
            return leftArea < rightArea
        }
    }

    private static func clampedSourceRect(for screenRect: CGRect, in displayFrame: CGRect) -> CGRect {
        let intersection = screenRect.intersection(displayFrame)
        // ScreenCaptureKit sourceRect uses display-local coordinates with top-left origin.
        let localYFromTop = displayFrame.maxY - intersection.maxY
        let local = CGRect(
            x: intersection.origin.x - displayFrame.origin.x,
            y: localYFromTop,
            width: intersection.width,
            height: intersection.height
        )
        return local.standardized
    }

    #if DEBUG
    private static func saveDebugImage(_ image: CGImage) {
        let url = URL(fileURLWithPath: "/tmp/screen-qr-last-capture.png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        if CGImageDestinationFinalize(destination) {
            print("[CaptureDebug] saved captured image: \(url.path)")
        }
    }

    private static func pretty(_ rect: CGRect) -> String {
        "x:\(String(format: "%.2f", rect.origin.x)) y:\(String(format: "%.2f", rect.origin.y)) w:\(String(format: "%.2f", rect.width)) h:\(String(format: "%.2f", rect.height))"
    }
    #endif
}

private extension CGRect {
    var area: CGFloat { width * height }
}
