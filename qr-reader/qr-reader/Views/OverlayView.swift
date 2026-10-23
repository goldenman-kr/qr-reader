import SwiftUI
import Combine

struct OverlayView: View {
    @ObservedObject var viewModel: MainViewModel
    @EnvironmentObject private var resultsStore: ScanResultsStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    private let phoneSize = PhoneLayout.phoneSize
    @State private var showNoResultAlert = false
    @State private var scannerWindow: NSWindow?

    var body: some View {
        ZStack {
            PhoneCameraFrameView(
                size: phoneSize,
                onShutterTap: { viewModel.captureAndScan() },
                selectedSourceTitle: viewModel.selectedSourceTitle,
                selectedSource: viewModel.selectedSource,
                sourceOptions: viewModel.sourceOptions.map { .init(source: $0.source, title: $0.title) },
                statusMessage: viewModel.statusMessage,
                onSelectSource: { source in
                    viewModel.selectSource(source)
                },
                onRefreshCameras: { viewModel.refreshCameraDevices() },
                onCameraMode: { viewModel.selectCameraMode() },
                onClose: { scannerWindow?.close() },
                onHistory: { openWindow(id: "history-window") }
            ) {
                if viewModel.shouldShowCameraPreview {
                    CameraPreviewView(session: viewModel.cameraSession)
                } else {
                    PreviewPlaceholderView()
                }
            }


        }
        .frame(width: phoneSize.width, height: phoneSize.height)
        .ignoresSafeArea()
        .background(Color.clear)
        .background(
            WindowConfigurator { window in
                scannerWindow = window
                // Make only the hole transparent; keep phone body solid.
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = true
                window.isMovableByWindowBackground = true
                window.level = .floating
                if window.contentLayoutRect.size != phoneSize {
                    window.setContentSize(phoneSize)
                }
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.isExcludedFromWindowsMenu = true
            }
        )
        .background(
            WindowContentRectReader { contentRect, windowFrame in
                viewModel.updateWindowContentRectInScreen(contentRect)
                viewModel.updateWindowFrameInScreen(windowFrame)
            }
        )
        .onAppear {
            viewModel.refreshScreenPermission()
            viewModel.refreshCameraDevices()
            viewModel.resumeCameraIfNeeded()
        }
        .onDisappear {
            viewModel.pauseCamera()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.resumeCameraIfNeeded()
            case .inactive, .background:
                viewModel.pauseCamera()
            @unknown default:
                viewModel.pauseCamera()
            }
        }
        .onChange(of: viewModel.latestResults) { _, newResults in
            if newResults.isEmpty {
                showNoResultAlert = true
                return
            }
            resultsStore.update(with: newResults)
            openWindow(id: "scan-results-window")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHistoryFromAppMenu)) { _ in
            openWindow(id: "history-window")
        }
        // .alert("No QR code found", isPresented: $showNoResultAlert) {
        //     Button("OK", role: .cancel) {}
        // } message: {
        //     Text("Try moving the scanner frame over a QR code and capture again.")
        // }
    }
}

#Preview {
    let store = UserDefaultsHistoryStore()
    let results = ScanResultsStore()
    OverlayView(viewModel: MainViewModel(historyStore: store))
        .environmentObject(store)
        .environmentObject(results)
}
