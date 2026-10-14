import SwiftlyFeedbackKit
import SwiftUI

/// The README's usage samples, compiled against the package.
///
/// `swift test` typechecks this file. A sample that names a removed property, or that
/// reads a member on an optional result, fails here.
@MainActor
enum READMESamples {
    static func configuration() {
        SwiftlyFeedback.configuration.allowUndoVote = true
        SwiftlyFeedback.configuration.showVoteCount = true
        SwiftlyFeedback.configuration.showStatusBadge = true
        SwiftlyFeedback.configuration.showCategoryBadge = true
        SwiftlyFeedback.configuration.showEmailField = true
        SwiftlyFeedback.configuration.showCommentSection = true
        SwiftlyFeedback.configuration.listStyle = .showcase
        SwiftlyFeedback.configuration.buttons.addButton.display = true
        SwiftlyFeedback.configuration.buttons.statusFilter.display = true
        SwiftlyFeedback.configuration.buttons.categoryFilter.display = true
        SwiftlyFeedback.configuration.allowFeedbackSubmission = false
        SwiftlyFeedback.configuration.feedbackSubmissionDisabledMessage = "Upgrade to Pro to submit feedback"
        SwiftlyFeedback.configuration.userEmail = "user@example.com"
        SwiftlyFeedback.configuration.showVoteEmailField = true
        SwiftlyFeedback.configuration.voteNotificationDefaultOptIn = false
        SwiftlyFeedback.configuration.onUserEmailChanged = { email in
            UserDefaults.standard.set(email ?? "", forKey: "userEmail")
        }
        SwiftlyFeedback.configuration.loggingEnabled = false

        SwiftlyFeedback.appearance.primaryColor = .color(.blue)
        SwiftlyFeedback.appearance.primaryColor = .adaptive(light: .blue, dark: .cyan)
        SwiftlyFeedback.appearance.primaryColor = .default
        SwiftlyFeedback.appearance.statusColors.pending = .color(.gray)
        SwiftlyFeedback.appearance.statusColors.approved = .color(.blue)
        SwiftlyFeedback.appearance.statusColors.inProgress = .color(.orange)
        SwiftlyFeedback.appearance.statusColors.testflight = .color(.cyan)
        SwiftlyFeedback.appearance.statusColors.completed = .color(.green)
        SwiftlyFeedback.appearance.statusColors.rejected = .color(.red)
        SwiftlyFeedback.appearance.categoryColors.featureRequest = .color(.purple)
        SwiftlyFeedback.appearance.categoryColors.bugReport = .color(.red)
        SwiftlyFeedback.appearance.categoryColors.improvement = .color(.teal)
        SwiftlyFeedback.appearance.categoryColors.other = .color(.gray)
    }

    static func directAPI(feedbackId: UUID) async throws {
        _ = try await SwiftlyFeedback.current?.getFeedback()
        _ = try await SwiftlyFeedback.current?.getFeedback(status: .pending)
        _ = try await SwiftlyFeedback.current?.getFeedback(category: .bugReport)
        _ = try await SwiftlyFeedback.current?.getFeedback(status: .pending, category: .bugReport)
        _ = try await SwiftlyFeedback.current?.getFeedback(id: feedbackId)

        _ = try await SwiftlyFeedback.current?.submitFeedback(
            title: "Dark mode support",
            description: "It would be great to have a dark mode option...",
            category: .featureRequest,
            email: "user@example.com"
        )

        if let result = try await SwiftlyFeedback.current?.vote(for: feedbackId) {
            print("New vote count: \(result.voteCount)")
        }
        _ = try await SwiftlyFeedback.current?.vote(
            for: feedbackId,
            email: "user@example.com",
            notifyStatusChange: true
        )
        _ = try await SwiftlyFeedback.current?.unvote(for: feedbackId)
        _ = try await SwiftlyFeedback.current?.getComments(for: feedbackId)
        _ = try await SwiftlyFeedback.current?.addComment(to: feedbackId, content: "Thanks for the suggestion!")

        SwiftlyFeedback.updateUser(customID: "user_123")
        SwiftlyFeedback.updateUser(payment: .monthly(9.99))
        SwiftlyFeedback.view("feature_details", properties: ["id": "abc123"])
        SwiftlyFeedback.view(.feedbackList)
    }

    static func errors() async {
        do {
            _ = try await SwiftlyFeedback.current?.submitFeedback(
                title: "My idea",
                description: "Details...",
                category: .featureRequest
            )
        } catch let error as SwiftlyFeedbackError {
            switch error {
            case .invalidApiKey:
                break
            case .feedbackLimitReached(let message):
                _ = message
            case .networkError(let underlying):
                _ = underlying
            case .unauthorized:
                break
            case .notFound:
                break
            case .badRequest(let message):
                _ = message
            case .conflict:
                break
            case .serverError(let statusCode):
                _ = statusCode
            case .decodingError(let underlying):
                _ = underlying
            case .forbidden(let message):
                _ = message
            case .rateLimited(let message):
                _ = message
            case .tierUpgradeRequired(let code, let message):
                _ = (code, message)
            case .measureNotAvailable(let measure, _):
                _ = measure
            case .invalidResponse:
                break
            }
        } catch {
            _ = error.localizedDescription
        }
    }

    static func views() -> some View {
        VStack {
            FeedbackListView()
            SubmitFeedbackView { }
        }
    }
}
