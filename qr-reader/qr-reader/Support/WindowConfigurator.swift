import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    var configure: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(configure: configure)
    }

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.configureIfNeeded(window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {
        context.coordinator.configure = configure
        context.coordinator.configureIfNeeded(nsView.window)
    }

    final class Coordinator {
        var configure: (NSWindow) -> Void
        private weak var configuredWindow: NSWindow?

        init(configure: @escaping (NSWindow) -> Void) {
            self.configure = configure
        }

        func configureIfNeeded(_ window: NSWindow?) {
            guard let window, configuredWindow !== window else { return }
            configuredWindow = window
            configure(window)
        }
    }
}

final class WindowAccessorView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
