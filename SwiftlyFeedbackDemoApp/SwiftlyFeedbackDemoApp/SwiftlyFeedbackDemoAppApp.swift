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
        // Configure the SDK with automatic environment detection
        // DEBUG → localhost:8080
        // TestFlight → staging server
        // App Store → production server
        SwiftlyFeedback.configureAuto(with: "sf_G3VStALGZ3Ja8LhWPKJTRJk9S8RaZwMk")

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
