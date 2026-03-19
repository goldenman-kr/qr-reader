import SwiftUI
import Combine

struct OverlayView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var resultsStore: ScanResultsStore
    @Environment(\.openWindow) private var openWindow
    private let phoneSize = PhoneLayout.phoneSize
    @State private var showNoResultAlert = false

    var body: some View {
        ZStack {
            PhoneCameraFrameView(
                size: phoneSize,
                onShutterTap: { viewModel.captureAndScan() },
                selectedSource: viewModel.selectedSource,
                onSelectSource: { source in
                    viewModel.selectedSource = source
                }
            ) {
                PreviewPlaceholderView()
            }

            VStack {
                Text("QR Reader")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.top, 10)
                Spacer()
            }

            VStack {
                Spacer()
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
            }
        }
        .frame(width: phoneSize.width, height: phoneSize.height)
        .background(Color.clear)
        .background(
            WindowConfigurator { window in
                // Make only the hole transparent; keep phone body solid.
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
                window.isMovableByWindowBackground = true
                window.level = .floating
                window.styleMask = [.titled, .closable, .fullSizeContentView]
                window.setContentSize(phoneSize)
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.standardWindowButton(.closeButton)?.isHidden = false
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.isExcludedFromWindowsMenu = true
                viewModel.updateWindowFrameInScreen(window.frame)
                let contentRect = window.convertToScreen(window.contentLayoutRect)
                viewModel.updateWindowContentRectInScreen(contentRect)
            }
        )
        .onAppear {
            viewModel.refreshScreenPermission()
        }
        .onChange(of: viewModel.latestResults) { _, newResults in
            if newResults.isEmpty {
                showNoResultAlert = true
                return
            }
            resultsStore.update(with: newResults)
            openWindow(id: "scan-results-window")
        }
        .onChange(of: viewModel.debugCaptureVersion) { _, _ in
            openWindow(id: "captured-image-debug-window")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHistoryFromAppMenu)) { _ in
            openWindow(id: "history-window")
        }
        .alert("No QR code found", isPresented: $showNoResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try moving the scanner frame over a QR code and capture again.")
        }
    }
}

#Preview {
    let store = UserDefaultsHistoryStore()
    let results = ScanResultsStore()
    OverlayView(viewModel: MainViewModel(historyStore: store))
        .environmentObject(store)
        .environmentObject(results)
}
