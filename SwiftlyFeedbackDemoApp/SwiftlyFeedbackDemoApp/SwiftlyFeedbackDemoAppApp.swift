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

    init() {
        // 1. Configure the SDK with your API key
        SwiftlyFeedback.configure(with: "sf_BDcM1OmBAoijvu4cBzPD3g9qY6pYGohL")

        // 2. (Optional) Customize configuration
        SwiftlyFeedback.config.allowUndoVote = true
        SwiftlyFeedback.config.showCommentSection = true
        SwiftlyFeedback.config.expandDescriptionInList = false

        // 3. (Optional) Customize theme
        SwiftlyFeedback.theme.primaryColor = .color(.blue)
        SwiftlyFeedback.theme.statusColors.completed = .green

        // 4. (Optional) Set user payment for MRR tracking
        // Call this when user subscribes or updates their subscription
        SwiftlyFeedback.updateUser(payment: .monthly(9.99))

        // 5. (Optional) Set custom user ID to link with your user system
        // SwiftlyFeedback.updateUser(customID: "your-user-id")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
