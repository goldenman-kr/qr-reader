import SwiftUI

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Keep History under Window menu.
        CommandGroup(before: .windowArrangement) {
            Button("History") {
                openWindow(id: "history-window")
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])
            Divider()
        }

        // Remove default Edit menu sections.
        CommandGroup(replacing: .undoRedo) {}
        CommandGroup(replacing: .pasteboard) {}
        CommandGroup(replacing: .textEditing) {}
        CommandGroup(replacing: .textFormatting) {}

        // Remove default View menu sections.
        CommandGroup(replacing: .sidebar) {
        }
        CommandGroup(replacing: .toolbar) {
        }
        CommandGroup(replacing: .windowSize) {}
    }
}
