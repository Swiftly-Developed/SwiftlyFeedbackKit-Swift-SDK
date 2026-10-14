import Foundation
import OSLog
import os

/// Process-wide copy of `loggingEnabled` that log calls can read without hopping to the main actor.
///
/// `SwiftlyFeedbackConfiguration` is main-actor isolated. Launch configuration logs from a
/// detached task, so the flag itself lives in a lock. The configuration property's `didSet`
/// and the static configuration's `didSet` both write this gate.
enum SDKLogGate {
    private static let enabled = OSAllocatedUnfairLock(initialState: true)

    static var isEnabled: Bool {
        enabled.withLock { $0 }
    }

    static func setEnabled(_ value: Bool) {
        enabled.withLock { $0 = value }
    }
}

/// Internal logging utility that respects the `loggingEnabled` configuration.
enum SDKLogger {
    private static let logger = Logger(subsystem: "com.swiftlyfeedback.sdk", category: "SDK")
    private static let testingSink = OSAllocatedUnfairLock<(@Sendable (String) -> Void)?>(initialState: nil)

    /// Receives the same text OSLog receives. Tests use this to prove a line does not
    /// contain an API key or personal data. Production leaves it nil.
    static func setTestingSink(_ sink: (@Sendable (String) -> Void)?) {
        testingSink.withLock { $0 = sink }
    }

    private static func emit(_ message: String, write: (String) -> Void) {
        guard SDKLogGate.isEnabled else { return }
        testingSink.withLock { $0?(message) }
        write(message)
    }

    static func debug(_ message: String) {
        emit(message) { logger.debug("\($0)") }
    }

    static func info(_ message: String) {
        emit(message) { logger.info("\($0)") }
    }

    static func warning(_ message: String) {
        emit(message) { logger.warning("\($0)") }
    }

    static func error(_ message: String) {
        emit(message) { logger.error("\($0)") }
    }
}
