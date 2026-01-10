import Vapor
import Fluent

/// Scheduled cleanup service that automatically deletes feedback older than 7 days
/// on non-production environments (development, staging/testflight).
///
/// This helps keep test databases clean and prevents accumulation of test data.
enum FeedbackCleanupScheduler {
    /// Number of days after which feedback is deleted
    static let retentionDays = 7

    /// Interval between cleanup runs (24 hours)
    private static let cleanupInterval: TimeInterval = 24 * 60 * 60

    /// Starts the cleanup scheduler
    /// - Parameter app: The Vapor application instance
    static func start(app: Application) {
        let appEnv = AppEnvironment.shared

        // Only run on non-production environments
        guard !appEnv.isProduction else {
            app.logger.info("[FeedbackCleanup] Disabled - production environment")
            return
        }

        app.logger.info("[FeedbackCleanup] Enabled for \(appEnv.type.name) environment")
        app.logger.info("[FeedbackCleanup] Will delete feedback older than \(retentionDays) days")

        // Schedule the cleanup task
        Task {
            // Run initial cleanup after a short delay to let the app fully start
            try? await Task.sleep(for: .seconds(30))
            await runCleanup(app: app)

            // Then run every 24 hours
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(cleanupInterval))
                await runCleanup(app: app)
            }
        }
    }

    /// Performs the actual cleanup of old feedback
    @Sendable
    private static func runCleanup(app: Application) async {
        let appEnv = AppEnvironment.shared

        // Double-check we're not in production
        guard !appEnv.isProduction else { return }

        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)

        app.logger.info("[FeedbackCleanup] Starting cleanup...")
        app.logger.info("[FeedbackCleanup] Deleting feedback older than \(cutoffDate)")

        do {
            // Find all feedback older than cutoff date (excluding merged feedback)
            let oldFeedback = try await Feedback.query(on: app.db)
                .filter(\.$createdAt < cutoffDate)
                .filter(\.$mergedIntoId == nil)  // Don't delete if already merged
                .all()

            guard !oldFeedback.isEmpty else {
                app.logger.info("[FeedbackCleanup] No feedback older than \(retentionDays) days found")
                return
            }

            app.logger.info("[FeedbackCleanup] Found \(oldFeedback.count) feedback items to delete")

            var deletedCount = 0
            var errorCount = 0

            for feedback in oldFeedback {
                guard let feedbackId = feedback.id else { continue }

                do {
                    // Delete comments first (due to foreign key constraints)
                    try await Comment.query(on: app.db)
                        .filter(\.$feedback.$id == feedbackId)
                        .delete()

                    // Delete votes
                    try await Vote.query(on: app.db)
                        .filter(\.$feedback.$id == feedbackId)
                        .delete()

                    // Delete the feedback itself
                    try await feedback.delete(on: app.db)

                    deletedCount += 1
                    app.logger.debug("[FeedbackCleanup] Deleted feedback \(feedbackId)")
                } catch {
                    errorCount += 1
                    app.logger.error("[FeedbackCleanup] Failed to delete feedback \(feedbackId): \(error)")
                }
            }

            app.logger.info("[FeedbackCleanup] Completed: \(deletedCount) deleted, \(errorCount) errors")

        } catch {
            app.logger.error("[FeedbackCleanup] Failed to query feedback: \(error)")
        }
    }
}
