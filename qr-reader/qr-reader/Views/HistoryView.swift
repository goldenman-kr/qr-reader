import AppKit
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: UserDefaultsHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Clear") {
                    historyStore.clear()
                }
            }

            if historyStore.items.isEmpty {
                Text("No history yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(historyStore.items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.source.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(item.results) { result in
                                Text(result.payload)
                            }
                        }
                        Spacer(minLength: 8)
                        Button("Copy") {
                            copyHistoryItem(item)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            WindowConfigurator { window in
                window.isExcludedFromWindowsMenu = true
            }
        )
    }

    private func copyHistoryItem(_ item: ScanHistoryItem) {
        let payload = item.results.map(\.payload).joined(separator: "\n")
        guard !payload.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
    }
}

#Preview {
    HistoryView()
        .environmentObject(UserDefaultsHistoryStore())
}
