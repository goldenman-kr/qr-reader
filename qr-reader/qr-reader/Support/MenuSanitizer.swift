import AppKit

@MainActor
enum MenuSanitizer {
    private static var didInstallObservers = false

    static func applyNow() {
        guard let mainMenu = NSApp.mainMenu else { return }

        var removed: [String] = []
        for item in mainMenu.items.reversed() {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = title.lowercased()
            let shouldRemove =
                title == "View" || title == "Format" || title == "보기" || title == "서식" ||
                lower.contains("view") || lower.contains("format")
            if shouldRemove {
                removed.append(title)
                mainMenu.removeItem(item)
            }
        }

        if removed.isEmpty {
            print("[MenuSanitizer] removed: none")
        } else {
            print("[MenuSanitizer] removed: \(removed.joined(separator: ", "))")
        }
    }

    static func applyWithRetries() {
        DispatchQueue.main.async { applyNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { applyNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { applyNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { applyNow() }

        guard !didInstallObservers else { return }
        didInstallObservers = true

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            applyNow()
        }
    }
}
