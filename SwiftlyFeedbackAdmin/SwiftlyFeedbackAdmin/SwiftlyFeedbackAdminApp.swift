//
//  SwiftlyFeedbackAdminApp.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 03/01/2026.
//

import SwiftUI
import SwiftlyFeedbackKit

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

    @State private var deepLinkManager = DeepLinkManager.shared

    init() {
        // Configure subscription service at app launch
        SubscriptionService.shared.configure()

        // Configure SwiftlyFeedbackKit SDK for in-app feature requests
        // Uses environment-specific API key from AppConfiguration
        AppConfiguration.shared.configureSDK()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handleURL(url)
                }
        }
        #if os(macOS)
        .commands {
            DeveloperCommands()
        }
        #endif
    }
}

// MARK: - Developer Commands Menu (macOS)

#if os(macOS)
struct DeveloperCommands: Commands {
    var body: some Commands {
        if BuildEnvironment.canShowTestingFeatures {
            CommandGroup(after: .appSettings) {
                Button("Developer Commands...") {
                    DeveloperCommandsWindowController.shared.showWindow()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class DeveloperCommandsWindowController {
    static let shared = DeveloperCommandsWindowController()

    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let projectViewModel = ProjectViewModel()

        let contentView = DeveloperCommandsView(projectViewModel: projectViewModel, isStandaloneWindow: true)
            .frame(minWidth: 500, minHeight: 600)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Developer Commands"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 550, height: 650))
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window

        // Load projects
        Task {
            await projectViewModel.loadProjects()
        }
    }
}
#endif
