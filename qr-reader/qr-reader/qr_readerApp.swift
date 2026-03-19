//
//  qr_readerApp.swift
//  qr-reader
//
//  Created by Eddy Kim on 3/19/26.
//

import SwiftUI

@main
struct qr_readerApp: App {
    @StateObject private var historyStore = UserDefaultsHistoryStore()
    @StateObject private var resultsStore = ScanResultsStore()
    @StateObject private var mainViewModel: MainViewModel

    init() {
        let store = UserDefaultsHistoryStore()
        _historyStore = StateObject(wrappedValue: store)
        _mainViewModel = StateObject(wrappedValue: MainViewModel(historyStore: store))
    }

    var body: some Scene {
        WindowGroup {
            OverlayView(viewModel: mainViewModel)
                .environmentObject(historyStore)
                .environmentObject(resultsStore)
        }
        .defaultSize(width: 340, height: 700)
        .windowResizability(.contentSize)
        .commands {
            AppCommands()
        }

        Window("History", id: "history-window") {
            HistoryView()
                .environmentObject(historyStore)
        }
        .defaultSize(width: 460, height: 560)

        Window("Scan Results", id: "scan-results-window") {
            ScanResultsView()
                .environmentObject(resultsStore)
        }
        .defaultSize(width: 560, height: 380)

        Window("Captured Image Debug", id: "captured-image-debug-window") {
            CapturedImageDebugView(viewModel: mainViewModel)
        }
        .defaultSize(width: 620, height: 460)
    }
}
