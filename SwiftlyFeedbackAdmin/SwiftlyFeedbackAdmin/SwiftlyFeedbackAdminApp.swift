//
//  SwiftlyFeedbackAdminApp.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 03/01/2026.
//

import SwiftUI

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Synchronously logout when app is quitting
        logoutOnTermination()
    }

    private func logoutOnTermination() {
        guard KeychainService.getToken() != nil else { return }

        // Try to invalidate token on server (best effort, synchronous)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await AdminAPIClient.shared.post(path: "auth/logout", requiresAuth: true)
            } catch {
                // Ignore errors - we'll delete the token locally anyway
            }
            semaphore.signal()
        }
        // Wait briefly for the server call, but don't block termination too long
        _ = semaphore.wait(timeout: .now() + 1.0)

        // Delete local token after server call
        KeychainService.deleteToken()
    }
}
#endif

@main
struct SwiftlyFeedbackAdminApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        // Configure subscription service at app launch
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
