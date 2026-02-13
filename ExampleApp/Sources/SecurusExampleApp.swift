// ============================================================================
// SecurusExampleApp.swift
// SecurusExampleApp
//
// SwiftUI app entry point that configures and starts the Securus SDK.
// ============================================================================

import SwiftUI
import SecurusCore

@main
struct SecurusExampleApp: App {

    @State private var viewModel = SecurusViewModel()

    init() {
        // Configure the SDK with a demo API key and debug logging
        let config = SecurusConfiguration(
            apiKey: "sk_example_dev_key_12345",
            enableNetworkMonitoring: true,
            enableRuntimeProtection: true,
            logLevel: .debug
        )
        SecurusAgent.shared.configure(configuration: config)
        SecurusAgent.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
    }
}
