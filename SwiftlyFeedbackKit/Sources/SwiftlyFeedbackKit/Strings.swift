import SwiftUI

/// Localized strings for SwiftlyFeedback SDK.
///
/// Uses String Catalogs for type-safe localization.
/// Override strings via `SwiftlyFeedback.config.localization`.
public enum Strings {

    // MARK: - Feedback List

    public static var feedbackListTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.list.title", bundle: .forClass(BundleToken.self))
    }

    public static var feedbackListEmpty: LocalizedStringResource {
        LocalizedStringResource("feedback.list.empty", bundle: .forClass(BundleToken.self))
    }

    public static var feedbackListEmptyDescription: LocalizedStringResource {
        LocalizedStringResource("feedback.list.empty.description", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Submit Feedback

    public static var submitFeedbackTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.submit.title", bundle: .forClass(BundleToken.self))
    }

    public static var submitButton: LocalizedStringResource {
        LocalizedStringResource("button.submit", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Feedback Detail

    public static var feedbackDetailTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.detail.title", bundle: .forClass(BundleToken.self))
    }

    public static var commentsTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.detail.comments", bundle: .forClass(BundleToken.self))
    }

    public static var commentsEmpty: LocalizedStringResource {
        LocalizedStringResource("feedback.detail.comments.empty", bundle: .forClass(BundleToken.self))
    }

    public static var addCommentPlaceholder: LocalizedStringResource {
        LocalizedStringResource("feedback.detail.comments.add", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Form Fields

    public static var formTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.form.title", bundle: .forClass(BundleToken.self))
    }

    public static var formTitlePlaceholder: LocalizedStringResource {
        LocalizedStringResource("feedback.form.title.placeholder", bundle: .forClass(BundleToken.self))
    }

    public static var formDescription: LocalizedStringResource {
        LocalizedStringResource("feedback.form.description", bundle: .forClass(BundleToken.self))
    }

    public static var formDescriptionPlaceholder: LocalizedStringResource {
        LocalizedStringResource("feedback.form.description.placeholder", bundle: .forClass(BundleToken.self))
    }

    public static var formCategory: LocalizedStringResource {
        LocalizedStringResource("feedback.form.category", bundle: .forClass(BundleToken.self))
    }

    public static var formEmail: LocalizedStringResource {
        LocalizedStringResource("feedback.form.email", bundle: .forClass(BundleToken.self))
    }

    public static var formEmailPlaceholder: LocalizedStringResource {
        LocalizedStringResource("feedback.form.email.placeholder", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Buttons

    public static var cancelButton: LocalizedStringResource {
        LocalizedStringResource("button.cancel", bundle: .forClass(BundleToken.self))
    }

    public static var sendButton: LocalizedStringResource {
        LocalizedStringResource("button.send", bundle: .forClass(BundleToken.self))
    }

    public static var voteButton: LocalizedStringResource {
        LocalizedStringResource("button.vote", bundle: .forClass(BundleToken.self))
    }

    public static var votedButton: LocalizedStringResource {
        LocalizedStringResource("button.voted", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Status

    public static var statusPending: LocalizedStringResource {
        LocalizedStringResource("status.pending", bundle: .forClass(BundleToken.self))
    }

    public static var statusApproved: LocalizedStringResource {
        LocalizedStringResource("status.approved", bundle: .forClass(BundleToken.self))
    }

    public static var statusInProgress: LocalizedStringResource {
        LocalizedStringResource("status.inProgress", bundle: .forClass(BundleToken.self))
    }

    public static var statusCompleted: LocalizedStringResource {
        LocalizedStringResource("status.completed", bundle: .forClass(BundleToken.self))
    }

    public static var statusRejected: LocalizedStringResource {
        LocalizedStringResource("status.rejected", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Categories

    public static var categoryFeatureRequest: LocalizedStringResource {
        LocalizedStringResource("category.featureRequest", bundle: .forClass(BundleToken.self))
    }

    public static var categoryBugReport: LocalizedStringResource {
        LocalizedStringResource("category.bugReport", bundle: .forClass(BundleToken.self))
    }

    public static var categoryImprovement: LocalizedStringResource {
        LocalizedStringResource("category.improvement", bundle: .forClass(BundleToken.self))
    }

    public static var categoryOther: LocalizedStringResource {
        LocalizedStringResource("category.other", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Errors

    public static var errorTitle: LocalizedStringResource {
        LocalizedStringResource("error.title", bundle: .forClass(BundleToken.self))
    }

    public static var errorOK: LocalizedStringResource {
        LocalizedStringResource("error.ok", bundle: .forClass(BundleToken.self))
    }

    public static var errorGeneric: LocalizedStringResource {
        LocalizedStringResource("error.generic", bundle: .forClass(BundleToken.self))
    }

    public static var errorInvalidApiKeyTitle: LocalizedStringResource {
        LocalizedStringResource("error.invalidApiKey.title", bundle: .forClass(BundleToken.self))
    }

    public static var errorInvalidApiKeyMessage: LocalizedStringResource {
        LocalizedStringResource("error.invalidApiKey.message", bundle: .forClass(BundleToken.self))
    }

    public static var errorFeedbackLimitTitle: LocalizedStringResource {
        LocalizedStringResource("error.feedbackLimit.title", bundle: .forClass(BundleToken.self))
    }

    public static var errorFeedbackLimitMessage: LocalizedStringResource {
        LocalizedStringResource("error.feedbackLimit.message", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Feedback Submission Disabled

    public static var feedbackSubmissionDisabledTitle: LocalizedStringResource {
        LocalizedStringResource("feedback.submission.disabled.title", bundle: .forClass(BundleToken.self))
    }

    public static var feedbackSubmissionDisabledMessage: LocalizedStringResource {
        LocalizedStringResource("feedback.submission.disabled.message", bundle: .forClass(BundleToken.self))
    }

    // MARK: - Counts

    public static func votesCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("votes.count", bundle: .forClass(BundleToken.self))
    }

    public static func commentsCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource("comments.count", bundle: .forClass(BundleToken.self))
    }
}

// MARK: - Bundle Token

/// Token class used to locate the bundle for this Swift Package.
private final class BundleToken {}

extension LocalizedStringResource.BundleDescription {
    /// Returns the bundle for the SwiftlyFeedbackKit module.
    static func forClass(_: AnyClass.Type) -> Self {
        .atURL(Bundle.module.bundleURL)
    }
}
