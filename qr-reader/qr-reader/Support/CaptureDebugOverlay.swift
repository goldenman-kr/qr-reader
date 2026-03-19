import AppKit
import SwiftUI

@MainActor
final class CaptureDebugOverlay {
    static let shared = CaptureDebugOverlay()

    struct RectStyle {
        let rect: CGRect
        let color: NSColor
    }

    private var windows: [NSWindow] = []

    func flash(rects: [RectStyle], duration: TimeInterval = 0.8) {
        clear()
        for item in rects {
            let rect = item.rect.standardized
            guard rect.width > 1, rect.height > 1 else { continue }

            let hosting = NSHostingView(rootView: DebugRectView(color: Color(item.color)))
            let window = NSWindow(
                contentRect: rect,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .statusBar
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.contentView = hosting
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.clear()
        }
    }

    private func clear() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private struct DebugRectView: View {
    let color: Color

    var body: some View {
        Rectangle()
            .stroke(color, lineWidth: 2)
            .background(Color.clear)
    }
}
