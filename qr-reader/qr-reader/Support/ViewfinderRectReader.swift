import AppKit
import SwiftUI

struct ViewfinderRectReader: NSViewRepresentable {
    var onRectChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onRectChange = onRectChange
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onRectChange = onRectChange
        DispatchQueue.main.async {
            nsView.reportRectIfPossible()
        }
    }
}

final class ReportingView: NSView {
    var onRectChange: ((CGRect) -> Void)?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()

        guard let window else { return }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                self?.reportRectIfPossible()
            }
        )
        observers.append(
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                self?.reportRectIfPossible()
            }
        )
        reportRectIfPossible()
    }

    override func layout() {
        super.layout()
        reportRectIfPossible()
    }

    func reportRectIfPossible() {
        guard let window, let onRectChange else { return }
        let rectInWindow = convert(bounds, to: nil)
        let rectInScreen = window.convertToScreen(rectInWindow).standardized
        onRectChange(rectInScreen)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
