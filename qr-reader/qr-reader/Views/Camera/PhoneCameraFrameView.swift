import SwiftUI

struct PhoneCameraFrameView<PreviewContent: View>: View {
    let size: CGSize
    let onShutterTap: () -> Void
    let selectedSource: CaptureSource
    let onSelectSource: (CaptureSource) -> Void
    @ViewBuilder var previewContent: PreviewContent

    init(
        size: CGSize = CGSize(width: 320, height: 680),
        onShutterTap: @escaping () -> Void = {},
        selectedSource: CaptureSource = .screen,
        onSelectSource: @escaping (CaptureSource) -> Void = { _ in },
        @ViewBuilder previewContent: () -> PreviewContent
    ) {
        self.size = size
        self.onShutterTap = onShutterTap
        self.selectedSource = selectedSource
        self.onSelectSource = onSelectSource
        self.previewContent = previewContent()
    }

    var body: some View {
        GeometryReader { proxy in
            let fullRect = CGRect(origin: .zero, size: proxy.size)
            let viewfinderRect = PhoneLayout.viewfinderRect(in: fullRect.size)

            ZStack {
                PhoneBodyShape(
                    outerRect: fullRect,
                    cutoutRect: viewfinderRect,
                    outerRadius: PhoneLayout.outerCornerRadius,
                    cutoutRadius: PhoneLayout.viewfinderCornerRadius
                )
                // Body is fully opaque; only cutout remains transparent.
                .fill(Color(nsColor: NSColor(calibratedWhite: 0.01, alpha: 1.0)), style: FillStyle(eoFill: true))
                .overlay {
                    RoundedRectangle(cornerRadius: PhoneLayout.outerCornerRadius, style: .continuous)
                        .stroke(Color(nsColor: NSColor(calibratedWhite: 0.85, alpha: 1.0)), lineWidth: 1.1)
                }
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

                previewContent
                    .frame(width: viewfinderRect.width, height: viewfinderRect.height)
                    .position(x: viewfinderRect.midX, y: viewfinderRect.midY)

                RoundedRectangle(cornerRadius: PhoneLayout.viewfinderCornerRadius, style: .continuous)
                    .stroke(Color(nsColor: NSColor(calibratedWhite: 0.9, alpha: 1.0)), lineWidth: 1)
                    .frame(width: viewfinderRect.width, height: viewfinderRect.height)
                    .position(x: viewfinderRect.midX, y: viewfinderRect.midY)

                VStack(spacing: 0) {
                    notch
                        .padding(.top, 12)
                    Spacer()
                    controlsArea
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: size.width, height: size.height)
    }

    private var notch: some View {
        Capsule(style: .continuous)
            .fill(Color.black)
            .frame(width: min(size.width * 0.34, 132), height: 26)
            .overlay {
                Circle()
                    .fill(Color(nsColor: NSColor(calibratedWhite: 0.15, alpha: 1.0)))
                    .frame(width: 7, height: 7)
                    .offset(x: 32)
            }
    }

    private var controlsArea: some View {
        ZStack {
            Button(action: onShutterTap) {
                Circle()
                    .fill(.white)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Circle()
                            .stroke(.black.opacity(0.15), lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            
            HStack {
                Spacer()
                Menu {
                    Button("Screen") { onSelectSource(.screen) }
                    Button("Camera") { onSelectSource(.camera(deviceID: nil)) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.badge.person.crop")
                        Text(selectedSource.displayName)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: NSColor(calibratedWhite: 0.22, alpha: 1.0)))
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .frame(height: 84)
    }

}

private struct PhoneBodyShape: Shape {
    let outerRect: CGRect
    let cutoutRect: CGRect
    let outerRadius: CGFloat
    let cutoutRadius: CGFloat

    func path(in _: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: outerRadius, height: outerRadius))
        path.addRoundedRect(in: cutoutRect, cornerSize: CGSize(width: cutoutRadius, height: cutoutRadius))
        return path
    }
}

struct PreviewPlaceholderView: View {
    var body: some View {
        Color.clear
    }
}

#Preview("Phone Camera Frame") {
    PhoneCameraFrameView {
        PreviewPlaceholderView()
    }
    .padding(20)
    .background(Color(nsColor: .underPageBackgroundColor))
}
