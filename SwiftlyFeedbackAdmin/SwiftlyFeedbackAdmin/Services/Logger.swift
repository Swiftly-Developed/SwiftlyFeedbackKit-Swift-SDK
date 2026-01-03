import OSLog

/// Centralized logging for SwiftlyFeedback Admin app
/// Usage: Logger.api.debug("message") or Logger.viewModel.error("error")
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.swiftlyfeedback.admin"

    /// API client logging - network requests, responses, errors
    static let api = Logger(subsystem: subsystem, category: "API")

    /// Authentication logging - login, logout, token management
    static let auth = Logger(subsystem: subsystem, category: "Auth")

    /// ViewModel logging - state changes, data loading
    static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")

    /// View logging - lifecycle, user interactions
    static let view = Logger(subsystem: subsystem, category: "View")

    /// Data logging - model parsing, transformations
    static let data = Logger(subsystem: subsystem, category: "Data")

    /// Keychain logging - secure storage operations
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
}
