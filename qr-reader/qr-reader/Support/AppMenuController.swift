import AppKit

extension Notification.Name {
    static let openHistoryFromAppMenu = Notification.Name("openHistoryFromAppMenu")
}

@MainActor
final class AppMenuController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        buildMainMenu()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "App")
        appMenuItem.submenu = appMenu

        let appName =
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
            ProcessInfo.processInfo.processName
        appMenu.addItem(
            NSMenuItem(
                title: "Quit \(appName)",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        // Window menu (owned by app)
        let windowRootItem = NSMenuItem()
        mainMenu.addItem(windowRootItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.delegate = self
        windowRootItem.submenu = windowMenu
        windowRootItem.title = "Window"
        NSApp.windowsMenu = windowMenu
        rebuildWindowMenu(windowMenu)

        // Help menu
        let helpRootItem = NSMenuItem()
        mainMenu.addItem(helpRootItem)
        let helpMenu = NSMenu(title: "Help")
        helpRootItem.submenu = helpMenu
        helpRootItem.title = "Help"

        NSApp.mainMenu = mainMenu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu.title == "Window" {
            rebuildWindowMenu(menu)
        }
    }

    private func rebuildWindowMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let historyItem = NSMenuItem(title: "History", action: #selector(openHistoryWindow), keyEquivalent: "H")
        historyItem.keyEquivalentModifierMask = [.command, .shift]
        historyItem.target = self
        menu.addItem(historyItem)
    }

    @objc
    private func openHistoryWindow() {
        NotificationCenter.default.post(name: .openHistoryFromAppMenu, object: nil)
    }
}
