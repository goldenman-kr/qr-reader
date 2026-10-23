import SwiftUI

struct PhoneCameraFrameView<PreviewContent: View>: View {
    struct SourceOption: Identifiable {
        let source: CaptureSource
        let title: String
        var id: String { source.id }
    }

    let size: CGSize
    let onShutterTap: () -> Void
    let selectedSourceTitle: String
    let selectedSource: CaptureSource
    let sourceOptions: [SourceOption]
    let statusMessage: String
    let onSelectSource: (CaptureSource) -> Void
    let onRefreshCameras: () -> Void
    let onCameraMode: () -> Bool
    let onClose: () -> Void
    let onHistory: () -> Void
    @ViewBuilder var previewContent: () -> PreviewContent
    @State private var showingDevices = false

    private var cameraMode: Bool {
        if case .camera = selectedSource { return true }
        return false
    }

    private var cameras: [SourceOption] {
        sourceOptions.filter { if case .camera = $0.source { return true }; return false }
    }

    var body: some View {
        let viewport = PhoneLayout.viewfinderRect(in: size)
        ZStack(alignment: .top) {
            CameraHousing(hole: viewport)
                .fill(LinearGradient(colors: [Color(white: 0.18), Color(white: 0.075), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), style: FillStyle(eoFill: true))
            RoundedRectangle(cornerRadius: PhoneLayout.outerCornerRadius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.12), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .padding(1).allowsHitTesting(false)
            RoundedRectangle(cornerRadius: PhoneLayout.outerCornerRadius - 3, style: .continuous)
                .strokeBorder(.black.opacity(0.8), lineWidth: 2)
                .padding(3).allowsHitTesting(false)
            previewContent()
                .frame(width: viewport.width, height: viewport.height)
                .clipShape(RoundedRectangle(cornerRadius: PhoneLayout.viewfinderCornerRadius))
                .position(x: viewport.midX, y: viewport.midY)
            RoundedRectangle(cornerRadius: PhoneLayout.viewfinderCornerRadius)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                .frame(width: viewport.width, height: viewport.height)
                .position(x: viewport.midX, y: viewport.midY)
                .allowsHitTesting(false)
            VStack(spacing: 0) {
                HStack {
                    iconButton("xmark", help: "Close scanner", action: onClose)
                        .keyboardShortcut("w", modifiers: .command)
                    Spacer()
                    Text("Mr. QR").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    iconButton("clock.arrow.circlepath", help: "Scan history", action: onHistory)
                }
                .padding(.horizontal, 18)
                .frame(height: viewport.minY)
                Spacer(minLength: 0)
                controls.frame(height: size.height - viewport.maxY)
            }
        }
        .frame(width: size.width, height: size.height)
        .preferredColorScheme(.dark)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                modeButton("Screen", icon: "display", selected: !cameraMode) {
                    onSelectSource(.screen)
                }
                modeButton("Camera", icon: "camera", selected: cameraMode) {
                    showingDevices = onCameraMode()
                }
            }
            .padding(3)
            .background(.black.opacity(0.25), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
            Button {
                onRefreshCameras()
                showingDevices = true
            } label: {
                HStack(spacing: 5) {
                    Text(cameraMode ? selectedSourceTitle : "Choose camera").lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: 250).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingDevices, arrowEdge: .top) { devicePicker }
            Button(action: onShutterTap) {
                Circle().fill(.white).padding(5)
                    .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 2))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help("Capture and scan · Space").accessibilityLabel("Capture and scan")
            Text(["Ready", "Screen mode.", "Camera mode."].contains(statusMessage) ? "Space to capture" : statusMessage)
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                .lineLimit(1).padding(.horizontal, 20)
        }
        .padding(.top, 8).padding(.bottom, 12)
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Camera").font(.headline)
                Spacer()
                Button(action: onRefreshCameras) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("Refresh cameras")
            }
            if cameras.isEmpty {
                Text("No connected cameras").foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(cameras) { camera in
                            Button {
                                onSelectSource(camera.source)
                                showingDevices = false
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "video")
                                    Text(camera.title).lineLimit(2)
                                    Spacer()
                                    if camera.source == selectedSource {
                                        Image(systemName: "checkmark").fontWeight(.semibold)
                                    }
                                }
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(camera.source == selectedSource ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: min(CGFloat(cameras.count) * 48, 240))
            }
        }
        .padding(16).frame(width: 280)
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8)).frame(width: 30, height: 30)
                .background(.white.opacity(0.055), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }

    private func modeButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.5))
                .frame(width: 100, height: 26)
                .background(selected ? Color.white.opacity(0.14) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CameraHousing: Shape {
    let hole: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: PhoneLayout.outerCornerRadius, height: PhoneLayout.outerCornerRadius))
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: PhoneLayout.viewfinderCornerRadius, height: PhoneLayout.viewfinderCornerRadius))
        return path
    }
}

struct PreviewPlaceholderView: View {
    var body: some View { Color.clear }
}
