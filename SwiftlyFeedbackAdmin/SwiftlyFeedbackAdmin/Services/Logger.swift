import OSLog

// MARK: - AppLogger

/// Centralized logging for SwiftlyFeedback Admin app.
///
/// Explicitly marked as `nonisolated` to opt out of the project's default MainActor isolation.
/// All loggers and methods are thread-safe and can be called from any actor or thread.
///
/// Usage:
/// ```swift
/// AppLogger.api.info("Loading projects...")
/// AppLogger.auth.error("Login failed")
/// AppLogger.viewModel.debug("State changed")
/// ```
///
/// To disable logging:
/// ```swift
/// AppLogger.isEnabled = false
/// ```

// MARK: - Private State

/// Subsystem identifier for OSLog.
/// Using nonisolated(unsafe) to opt out of MainActor isolation since this is a constant string.
private nonisolated let loggerSubsystem = "com.swiftlyfeedback.admin"

/// Thread-safe logging enabled flag.
/// Using nonisolated(unsafe) is appropriate here because:
/// 1. This is a simple boolean flag with atomic read/write on most architectures
/// 2. The worst case of a data race is a log message being printed or not - no safety issue
/// 3. This avoids complex locking that can cause actor isolation inference issues
nonisolated(unsafe) private var _loggingEnabled = true

// MARK: - AppLogger

/// Namespace for accessing loggers.
/// Marked `nonisolated` to opt out of project-wide MainActor default isolation.
nonisolated
enum AppLogger {
    /// Subsystem used for all loggers
    private static let subsystem = loggerSubsystem

    /// Enable or disable all Admin app logging. Default: `true`
    static var isEnabled: Bool {
        get { _loggingEnabled }
        set { _loggingEnabled = newValue }
    }

    /// API client logging - network requests, responses, errors
    static let api = LoggerWrapper(category: "API")

    /// Authentication logging - login, logout, token management
    static let auth = LoggerWrapper(category: "Auth")

    /// ViewModel logging - state changes, data loading
    static let viewModel = LoggerWrapper(category: "ViewModel")

    /// View logging - lifecycle, user interactions
    static let view = LoggerWrapper(category: "View")

    /// Data logging - model parsing, transformations
    static let data = LoggerWrapper(category: "Data")

    /// Keychain logging - secure storage operations
    static let keychain = LoggerWrapper(category: "Keychain")

    /// Subscription logging - RevenueCat, purchases, entitlements
    static let subscription = LoggerWrapper(category: "Subscription")
}

// MARK: - LoggerWrapper

/// A wrapper around OSLog Logger that respects the global logging enabled flag.
///
/// Thread-safe and Sendable. Can be called from any actor or thread.
/// Marked `nonisolated` to opt out of project-wide MainActor default isolation.
///
/// Marked as `@unchecked Sendable` because OSLog.Logger is thread-safe (confirmed by Apple)
/// but not yet marked as Sendable in the SDK. See: https://developer.apple.com/forums/thread/747816
nonisolated
struct LoggerWrapper: @unchecked Sendable {
    private let logger: Logger

    init(category: String) {
        self.logger = Logger(subsystem: loggerSubsystem, category: category)
    }

    func debug(_ message: String) {
        guard _loggingEnabled else { return }
        logger.debug("\(message)")
    }

    func info(_ message: String) {
        guard _loggingEnabled else { return }
        logger.info("\(message)")
    }

    func error(_ message: String) {
        guard _loggingEnabled else { return }
        logger.error("\(message)")
    }

    func warning(_ message: String) {
        guard _loggingEnabled else { return }
        logger.warning("\(message)")
    }
}
