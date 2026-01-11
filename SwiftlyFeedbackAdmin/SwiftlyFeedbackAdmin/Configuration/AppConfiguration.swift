//
//  AppConfiguration.swift
//  SwiftlyFeedbackAdmin
//
//  Global configuration manager for environment and server URL management
//

import Foundation
import SwiftUI

// MARK: - Environment Change Notification

extension Notification.Name {
    /// Posted when the app environment changes
    /// The notification object is the new `AppEnvironment` value
    static let environmentDidChange = Notification.Name("environmentDidChange")
}

/// Environment configuration options
enum AppEnvironment: String, Codable, CaseIterable {
    case localhost
    case development
    case testflight
    case production

    var displayName: String {
        switch self {
        case .localhost: return "Localhost"
        case .development: return "Development"
        case .testflight: return "TestFlight"
        case .production: return "Production"
        }
    }

    /// Color associated with this environment for visual identification
    var color: Color {
        switch self {
        case .localhost: return .purple
        case .development: return .blue
        case .testflight: return .orange
        case .production: return .red
        }
    }

    /// Whether this environment is available for the current build type
    var isAvailable: Bool {
        switch self {
        case .localhost, .development:
            return BuildEnvironment.isDebug
        case .testflight:
            return BuildEnvironment.isDebug || BuildEnvironment.isTestFlight
        case .production:
            return true
        }
    }

    /// Environments available for selection in current build
    static var availableEnvironments: [AppEnvironment] {
        allCases.filter { $0.isAvailable }
    }

    var baseURL: String {
        switch self {
        case .localhost:
            return "http://localhost:8080"
        case .development:
            return "https://api.feedbackkit.dev.swiftly-developed.com"
        case .testflight:
            return "https://api.feedbackkit.testflight.swiftly-developed.com"
        case .production:
            return "https://api.feedbackkit.prod.swiftly-developed.com"
        }
    }

    /// Whether this environment is a remote server (not localhost)
    var isRemote: Bool {
        self != .localhost
    }

    /// The remote environments available (excludes localhost)
    static var remoteEnvironments: [AppEnvironment] {
        [.development, .testflight, .production]
    }

    /// All environments available in DEBUG builds
    static var debugEnvironments: [AppEnvironment] {
        allCases
    }

    /// Environments available in TestFlight builds (testflight and production only)
    static var testFlightBuildEnvironments: [AppEnvironment] {
        [.testflight, .production]
    }

    // MARK: - SwiftlyFeedbackKit SDK API Keys
    // These are the API keys for the Admin app's own feedback project (dog-fooding)
    // Each environment has its own project with a separate API key

    /// SDK API key for the Admin app's feedback project in this environment
    var sdkAPIKey: String {
        switch self {
        case .localhost:
            return "sf_80OfWg1185nExqUsc8ivmBo84GMRL5fs"
        case .development:
            return "sf_67xRwr4qxTwaIQOFyXq9uyuSOrtS2uvy"
        case .testflight:
            return "sf_Gw8ZKcjCEtxHUNCKjpusOkFvlNbQ2Pxf"
        case .production:
            return "sf_Tt5Oc4SFNhNgGUb9Ga7Y7AMwF9cGj571"
        }
    }
}

/// Global configuration manager for app-wide settings
@MainActor
@Observable
final class AppConfiguration {
    // MARK: - Properties

    /// Shared singleton instance
    static let shared = AppConfiguration()

    private let userDefaults: UserDefaults
    private let environmentKey = "com.swiftlyfeedback.admin.environment"

    /// Current environment setting
    var environment: AppEnvironment {
        didSet {
            #if DEBUG
            // In DEBUG mode, allow changing environment and save it
            userDefaults.set(environment.rawValue, forKey: environmentKey)
            #else
            // In RELEASE mode (TestFlight or Production)
            if BuildEnvironment.isTestFlight {
                // TestFlight: Allow testflight or production (for testing)
                if !AppEnvironment.testFlightBuildEnvironments.contains(environment) {
                    print("⚠️ \(environment.displayName) not allowed in TestFlight - switching to TestFlight")
                    environment = .testflight
                } else {
                    userDefaults.set(environment.rawValue, forKey: environmentKey)
                }
            } else {
                // Production (App Store): Lock to production only
                if environment != .production {
                    print("⚠️ Production builds must use Production environment")
                    environment = .production
                }
            }
            #endif
        }
    }

    /// Current base URL based on environment
    var baseURL: String {
        environment.baseURL
    }

    /// Current API v1 base URL (baseURL + /api/v1)
    var apiV1URL: String {
        baseURL + "/api/v1"
    }

    /// Convenience property for checking if using localhost
    var isLocalhost: Bool {
        environment == .localhost
    }

    /// Convenience property for checking if in development mode
    var isDevelopmentMode: Bool {
        environment == .development
    }

    /// Convenience property for checking if in testflight mode
    var isTestFlightMode: Bool {
        environment == .testflight
    }

    /// Convenience property for checking if in production mode
    var isProductionMode: Bool {
        environment == .production
    }

    /// Available environments based on build type
    var availableEnvironments: [AppEnvironment] {
        #if DEBUG
        return AppEnvironment.debugEnvironments
        #else
        if BuildEnvironment.isTestFlight {
            return AppEnvironment.testFlightBuildEnvironments
        } else {
            return [.production]
        }
        #endif
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        #if DEBUG
        // DEBUG mode: Load saved environment or default to development
        if let savedEnv = userDefaults.string(forKey: environmentKey),
           let env = AppEnvironment(rawValue: savedEnv) {
            self.environment = env
        } else {
            self.environment = .development
        }

        // Override with launch arguments for testing
        if CommandLine.arguments.contains("--localhost") {
            self.environment = .localhost
        } else if CommandLine.arguments.contains("--dev-mode") {
            self.environment = .development
        } else if CommandLine.arguments.contains("--testflight-mode") {
            self.environment = .testflight
        } else if CommandLine.arguments.contains("--prod-mode") {
            self.environment = .production
        }
        #else
        // RELEASE mode: Behavior depends on build type
        if BuildEnvironment.isTestFlight {
            // TestFlight build: Load saved testflight/production or default to testflight
            if let savedEnv = userDefaults.string(forKey: environmentKey),
               let env = AppEnvironment(rawValue: savedEnv),
               AppEnvironment.testFlightBuildEnvironments.contains(env) {
                self.environment = env
            } else {
                self.environment = .testflight
            }
        } else {
            // Production (App Store): Always use production
            self.environment = .production
        }
        #endif

        #if DEBUG
        print("🔧 App Configuration Initialized")
        print("📍 Environment: \(environment.displayName)")
        print("🌐 Base URL: \(baseURL)")
        #endif
    }
}

// MARK: - Convenient Global Access
extension AppConfiguration {
    /// Quick access to base URL
    static var baseURL: String {
        shared.baseURL
    }

    /// Quick access to API v1 URL
    static var apiV1URL: String {
        shared.apiV1URL
    }

    /// Quick access to current environment
    static var currentEnvironment: AppEnvironment {
        shared.environment
    }

    /// Quick access to development mode status
    static var isDevelopmentMode: Bool {
        shared.isDevelopmentMode
    }

    /// Quick access to testflight mode status
    static var isTestFlightMode: Bool {
        shared.isTestFlightMode
    }

    /// Quick access to production mode status
    static var isProductionMode: Bool {
        shared.isProductionMode
    }

    /// Quick access to SDK API key for current environment
    static var sdkAPIKey: String {
        shared.environment.sdkAPIKey
    }
}

// MARK: - URL Building
extension AppConfiguration {
    /// Safely construct a URL from the base URL and path
    /// - Parameter path: The path to append (should start with /)
    /// - Returns: A valid URL or nil if construction fails
    func url(path: String) -> URL? {
        let urlString = baseURL + path
        return URL(string: urlString)
    }

    /// Static convenience method for URL construction
    /// - Parameter path: The path to append (should start with /)
    /// - Returns: A valid URL or nil if construction fails
    static func url(path: String) -> URL? {
        shared.url(path: path)
    }
}

// MARK: - Environment Switching
extension AppConfiguration {
    /// Switch to a different environment
    /// - Parameter environment: The target environment
    /// - Parameter reconfigureSDK: Whether to reconfigure the SwiftlyFeedbackKit SDK (default: true)
    /// - Note: DEBUG allows all environments, TestFlight build allows testflight/production, Production is locked
    func switchTo(_ environment: AppEnvironment, reconfigureSDK: Bool = true) {
        let previousEnvironment = self.environment

        #if DEBUG
        self.environment = environment
        print("🔄 Switched to \(environment.displayName) environment")
        print("🌐 New Base URL: \(baseURL)")
        #else
        if BuildEnvironment.isTestFlight {
            // TestFlight build: Allow testflight or production only
            if AppEnvironment.testFlightBuildEnvironments.contains(environment) {
                self.environment = environment
                print("🔄 Switched to \(environment.displayName) environment")
                print("🌐 New Base URL: \(baseURL)")
            } else {
                print("⚠️ \(environment.displayName) not allowed in TestFlight build - using TestFlight")
                self.environment = .testflight
            }
        } else {
            // Production: Always lock to production
            print("⚠️ Environment switching disabled in Production builds - locked to Production")
            self.environment = .production
        }
        #endif

        // Post notification if environment actually changed
        if self.environment != previousEnvironment {
            NotificationCenter.default.post(name: .environmentDidChange, object: self.environment)
        }

        // Reconfigure SDK with new environment's API key
        if reconfigureSDK {
            reconfigureSDKForCurrentEnvironment()
        }
    }

    /// Reset to default environment
    /// - Note: DEBUG → Development, TestFlight build → TestFlight, Production → Production
    func resetToDefault() {
        #if DEBUG
        switchTo(.development)
        #else
        if BuildEnvironment.isTestFlight {
            switchTo(.testflight)
        } else {
            switchTo(.production)
        }
        #endif
    }

    /// Check if environment switching is allowed
    var canSwitchEnvironment: Bool {
        availableEnvironments.count > 1
    }
}

// MARK: - SwiftlyFeedbackKit SDK Configuration
import SwiftlyFeedbackKit
import SwiftUI

extension AppConfiguration {
    /// Configure the SwiftlyFeedbackKit SDK with the current environment's API key and base URL
    /// Call this at app launch and whenever the environment changes
    func configureSDK() {
        let apiKey = environment.sdkAPIKey
        let sdkBaseURL = URL(string: apiV1URL)!

        SwiftlyFeedback.configure(with: apiKey, baseURL: sdkBaseURL)
        SwiftlyFeedback.theme.primaryColor = .color(Color.blue)

        #if DEBUG
        print("📱 SwiftlyFeedbackKit SDK configured")
        print("   Environment: \(environment.displayName)")
        print("   API Key: \(apiKey.prefix(20))...")
        print("   Base URL: \(sdkBaseURL)")
        #endif
    }

    /// Reconfigure the SDK when environment changes
    /// This should be called after switching environments
    func reconfigureSDKForCurrentEnvironment() {
        configureSDK()
    }
}
