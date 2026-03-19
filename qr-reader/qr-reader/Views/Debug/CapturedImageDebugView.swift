import SwiftUI

struct CapturedImageDebugView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Captured Image Debug")
                .font(.title3)
                .bold()

            Text(infoText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Divider()

            if let image = viewModel.debugCapturedImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ContentUnavailableView("No captured image yet", systemImage: "camera.viewfinder")
            }
        }
        .padding(14)
        .frame(minWidth: 520, minHeight: 360)
    }

    private var infoText: String {
        let r = viewModel.debugCaptureRect
        let wf = viewModel.debugWindowFrameInScreen
        let wc = viewModel.windowContentRectInScreen
        let rectString = "x=\(Int(r.origin.x)), y=\(Int(r.origin.y)), w=\(Int(r.width)), h=\(Int(r.height))"
        let windowString = "x=\(Int(wf.origin.x)), y=\(Int(wf.origin.y)), w=\(Int(wf.width)), h=\(Int(wf.height))"
        let contentString = "x=\(Int(wc.origin.x)), y=\(Int(wc.origin.y)), w=\(Int(wc.width)), h=\(Int(wc.height))"
        let scaleString = String(format: "%.3f", viewModel.debugBackingScaleFactor)
        return "captureRect(screen pt): \(rectString)\nwindowFrame(screen pt): \(windowString)\nwindowContentRect(screen pt): \(contentString)\nbackingScaleFactor: \(scaleString) | captureDisplayHeight(px): \(viewModel.debugCaptureDisplayHeight)"
    }
}
