//
//  SwiftlyFeedbackDemoAppApp.swift
//  SwiftlyFeedbackDemoApp
//
//  Created by Ben Van Aken on 03/01/2026.
//

import SwiftUI
import SwiftlyFeedbackKit

@main
struct SwiftlyFeedbackDemoAppApp: App {
    @State private var settings = AppSettings()

    init() {
        // Configure the SDK with your API key
        SwiftlyFeedback.configure(with: "sf_SoCZZ2mWzdUEPPvWUAXgE7iTUjEbs9PJ")

        // Customize theme
        SwiftlyFeedback.theme.primaryColor = .color(.blue)
        SwiftlyFeedback.theme.statusColors.completed = .green
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 500)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        .defaultPosition(.center)
        #endif
    }
}
