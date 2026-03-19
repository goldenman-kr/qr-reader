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
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
    }
}

#Preview {
    HistoryView()
        .environmentObject(UserDefaultsHistoryStore())
}
