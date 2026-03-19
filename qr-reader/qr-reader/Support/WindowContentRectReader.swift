import AppKit
import SwiftUI

struct WindowContentRectReader: NSViewRepresentable {
    var onRectChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ContentRectReportingView {
        let view = ContentRectReportingView()
        view.onRectChange = onRectChange
        return view
    }

    func updateNSView(_ nsView: ContentRectReportingView, context: Context) {
        nsView.onRectChange = onRectChange
        DispatchQueue.main.async {
            nsView.reportContentRectIfPossible()
        }
    }
}

final class ContentRectReportingView: NSView {
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
                self?.reportContentRectIfPossible()
            }
        )
        observers.append(
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                self?.reportContentRectIfPossible()
            }
        )
        reportContentRectIfPossible()
    }

    override func layout() {
        super.layout()
        reportContentRectIfPossible()
    }

    func reportContentRectIfPossible() {
        guard let window, let onRectChange else { return }
        // contentLayoutRect is the actual SwiftUI layout area after titlebar chrome.
        let rectInScreen = window.convertToScreen(window.contentLayoutRect).standardized
        onRectChange(rectInScreen)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
