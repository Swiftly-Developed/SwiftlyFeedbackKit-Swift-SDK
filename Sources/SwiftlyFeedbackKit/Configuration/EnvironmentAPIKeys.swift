//
//  EnvironmentAPIKeys.swift
//  SwiftlyFeedbackKit
//
//  API keys for each server environment.
//

import Foundation

// MARK: - Environment

/// The server environment to connect to.
///
/// Use with `SwiftlyFeedback.configure(environment:key:)` to explicitly
/// specify which server environment to use.
///
/// ## Example
///
/// ```swift
/// #if DEBUG
/// SwiftlyFeedback.configure(environment: .development, key: "your-dev-key")
/// #elseif TESTFLIGHT
/// SwiftlyFeedback.configure(environment: .testflight, key: "your-staging-key")
/// #else
/// SwiftlyFeedback.configure(environment: .production, key: "your-prod-key")
/// #endif
/// ```
public enum Environment: Sendable {
    /// Development environment (localhost:8080)
    case development

    /// TestFlight/staging environment
    case testflight

    /// Production/App Store environment
    case production

    /// The server URL for this environment
    internal var serverURL: URL {
        switch self {
        case .development:
            return URL(string: "http://localhost:8080/api/v1")!
        case .testflight:
            return URL(string: "https://api.feedbackkit.testflight.swiftly-developed.com/api/v1")!
        case .production:
            return URL(string: "https://api.feedbackkit.prod.swiftly-developed.com/api/v1")!
        }
    }

    /// Human-readable name for logging
    internal var displayName: String {
        switch self {
        case .development:
            return "development (localhost)"
        case .testflight:
            return "staging (TestFlight)"
        case .production:
            return "production (App Store)"
        }
    }
}

// MARK: - EnvironmentAPIKeys

/// API keys for each server environment.
///
/// Use with `SwiftlyFeedback.configureAuto(keys:)` to automatically
/// select the correct API key based on the current build environment.
///
/// ## Example
///
/// ```swift
/// SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
///     debug: "sf_local_...",       // Optional: localhost
///     testflight: "sf_staging_...", // Required: staging server
///     production: "sf_prod_..."     // Required: production server
/// ))
/// ```
///
/// ## Environment Detection
///
/// | Build Type | Server | API Key Used |
/// |------------|--------|--------------|
/// | DEBUG | localhost:8080 | `debug` (or `testflight` if nil) |
/// | TestFlight | staging server | `testflight` |
/// | App Store | production server | `production` |
public struct EnvironmentAPIKeys: Sendable {

    /// API key for DEBUG builds running against localhost.
    /// If nil, the testflight key will be used for DEBUG builds.
    public let debug: String?

    /// API key for TestFlight builds running against the staging server.
    public let testflight: String

    /// API key for App Store builds running against the production server.
    public let production: String

    /// Creates environment-specific API key configuration.
    ///
    /// - Parameters:
    ///   - debug: API key for localhost (DEBUG builds). Defaults to nil,
    ///     which will use the testflight key for DEBUG builds.
    ///   - testflight: API key for the staging server (TestFlight builds).
    ///   - production: API key for the production server (App Store builds).
    public init(
        debug: String? = nil,
        testflight: String,
        production: String
    ) {
        self.debug = debug
        self.testflight = testflight
        self.production = production
    }

    /// Returns the appropriate API key for the current build environment.
    internal var currentKey: String {
        #if DEBUG
        // DEBUG: Use debug key if provided, otherwise fall back to testflight
        return debug ?? testflight
        #else
        if BuildEnvironment.isTestFlight {
            return testflight
        } else {
            return production
        }
        #endif
    }

    /// Returns the server URL for the current build environment.
    internal var currentServerURL: URL {
        #if DEBUG
        return URL(string: "http://localhost:8080/api/v1")!
        #else
        if BuildEnvironment.isTestFlight {
            return URL(string: "https://api.feedbackkit.testflight.swiftly-developed.com/api/v1")!
        } else {
            return URL(string: "https://api.feedbackkit.prod.swiftly-developed.com/api/v1")!
        }
        #endif
    }

    /// Returns a description of the current environment for logging.
    internal var currentEnvironmentName: String {
        #if DEBUG
        return "localhost (DEBUG)"
        #else
        if BuildEnvironment.isTestFlight {
            return "staging (TestFlight)"
        } else {
            return "production (App Store)"
        }
        #endif
    }
}
