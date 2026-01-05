import OSLog

/// Global logging enabled flag. Set to false to disable all Admin app logging.
///
/// Example:
/// ```swift
/// // In your App init or development settings
/// AppLogger.isEnabled = false
/// ```
nonisolated(unsafe) var isLoggingEnabled = true

/// Centralized logging for SwiftlyFeedback Admin app that respects `isLoggingEnabled`.
///
/// Usage:
/// ```swift
/// AppLogger.api.info("Loading projects...")
/// AppLogger.auth.error("Login failed")
/// AppLogger.viewModel.debug("State changed")
/// ```
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.swiftlyfeedback.admin"

    /// Enable or disable all Admin app logging. Default: `true`
    static var isEnabled: Bool {
        get { isLoggingEnabled }
        set { isLoggingEnabled = newValue }
    }

    /// API client logging - network requests, responses, errors
    static let api = LoggerWrapper(category: "API", subsystem: subsystem)

    /// Authentication logging - login, logout, token management
    static let auth = LoggerWrapper(category: "Auth", subsystem: subsystem)

    /// ViewModel logging - state changes, data loading
    static let viewModel = LoggerWrapper(category: "ViewModel", subsystem: subsystem)

    /// View logging - lifecycle, user interactions
    static let view = LoggerWrapper(category: "View", subsystem: subsystem)

    /// Data logging - model parsing, transformations
    static let data = LoggerWrapper(category: "Data", subsystem: subsystem)

    /// Keychain logging - secure storage operations
    static let keychain = LoggerWrapper(category: "Keychain", subsystem: subsystem)

    /// Subscription logging - RevenueCat, purchases, entitlements
    static let subscription = LoggerWrapper(category: "Subscription", subsystem: subsystem)
}

/// A wrapper around OSLog Logger that respects the global `isLoggingEnabled` flag.
struct LoggerWrapper: Sendable {
    private let logger: Logger

    init(category: String, subsystem: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    nonisolated func debug(_ message: String) {
        guard isLoggingEnabled else { return }
        logger.debug("\(message)")
    }

    nonisolated func info(_ message: String) {
        guard isLoggingEnabled else { return }
        logger.info("\(message)")
    }

    nonisolated func error(_ message: String) {
        guard isLoggingEnabled else { return }
        logger.error("\(message)")
    }

    nonisolated func warning(_ message: String) {
        guard isLoggingEnabled else { return }
        logger.warning("\(message)")
    }
}
