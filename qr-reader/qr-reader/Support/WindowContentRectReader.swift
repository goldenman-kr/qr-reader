import AppKit
import SwiftUI

struct WindowContentRectReader: NSViewRepresentable {
    var onRectChange: (_ contentRect: CGRect, _ windowFrame: CGRect) -> Void

    func makeNSView(context: Context) -> ContentRectReportingView {
        let view = ContentRectReportingView()
        view.onRectChange = onRectChange
        return view
    }

    func updateNSView(_ nsView: ContentRectReportingView, context: Context) {
        nsView.onRectChange = onRectChange
    }
}

final class ContentRectReportingView: NSView {
    var onRectChange: ((_ contentRect: CGRect, _ windowFrame: CGRect) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var lastContentRect: CGRect = .null
    private var lastWindowFrame: CGRect = .null

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        lastContentRect = .null
        lastWindowFrame = .null

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
        let contentRect = window.convertToScreen(window.contentLayoutRect).standardized
        let windowFrame = window.frame.standardized
        guard contentRect != lastContentRect || windowFrame != lastWindowFrame else { return }
        lastContentRect = contentRect
        lastWindowFrame = windowFrame
        onRectChange(contentRect, windowFrame)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
