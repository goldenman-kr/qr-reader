import AppKit
import SwiftUI

struct ScanResultsView: View {
    @EnvironmentObject private var resultsStore: ScanResultsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scan Results")
                    .font(.title3)
                    .bold()
                Spacer()
                if let scannedAt = resultsStore.scannedAt {
                    Text(scannedAt.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if resultsStore.items.isEmpty {
                ContentUnavailableView("No results", systemImage: "qrcode.viewfinder")
            } else {
                List(resultsStore.items) { result in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.payload)
                                .font(.body)
                                .textSelection(.enabled)
                            Text(result.symbology)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.payload, forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .frame(minWidth: 500, minHeight: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            WindowConfigurator { window in
                window.isExcludedFromWindowsMenu = true
            }
        )
    }
}

#Preview {
    let store = ScanResultsStore()
    store.update(with: [
        QRScanResult(payload: "https://example.com"),
        QRScanResult(payload: "WIFI:S:MyAP;T:WPA;P:password;;")
    ])
    return ScanResultsView()
        .environmentObject(store)
}
