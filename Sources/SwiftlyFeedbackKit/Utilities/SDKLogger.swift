import Foundation
import OSLog

/// Internal logging utility that respects the `loggingEnabled` configuration.
enum SDKLogger {
    private static let logger = Logger(subsystem: "com.swiftlyfeedback.sdk", category: "SDK")

    static func debug(_ message: String) {
        guard SwiftlyFeedback.config.loggingEnabled else { return }
        logger.debug("\(message)")
    }

    static func info(_ message: String) {
        guard SwiftlyFeedback.config.loggingEnabled else { return }
        logger.info("\(message)")
    }

    static func error(_ message: String) {
        guard SwiftlyFeedback.config.loggingEnabled else { return }
        logger.error("\(message)")
    }
}
