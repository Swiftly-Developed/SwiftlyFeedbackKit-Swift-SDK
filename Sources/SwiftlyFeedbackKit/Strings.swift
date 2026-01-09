import SwiftUI

/// Localized strings for SwiftlyFeedback SDK.
///
/// Uses String Catalogs for type-safe localization with the #bundle macro for automatic bundle resolution.
public enum Strings {

    // MARK: - Feedback List

    public static var feedbackListTitle: String {
        String(localized: "feedback.list.title", bundle: #bundle)
    }

    public static var feedbackListEmpty: String {
        String(localized: "feedback.list.empty", bundle: #bundle)
    }

    public static var feedbackListEmptyDescription: String {
        String(localized: "feedback.list.empty.description", bundle: #bundle)
    }

    // MARK: - Submit Feedback

    public static var submitFeedbackTitle: String {
        String(localized: "feedback.submit.title", bundle: #bundle)
    }

    public static var submitButton: String {
        String(localized: "button.submit", bundle: #bundle)
    }

    // MARK: - Feedback Detail

    public static var feedbackDetailTitle: String {
        String(localized: "feedback.detail.title", bundle: #bundle)
    }

    public static var commentsTitle: String {
        String(localized: "feedback.detail.comments", bundle: #bundle)
    }

    public static var commentsEmpty: String {
        String(localized: "feedback.detail.comments.empty", bundle: #bundle)
    }

    public static var addCommentPlaceholder: String {
        String(localized: "feedback.detail.comments.add", bundle: #bundle)
    }

    public static var feedbackSubmitted: String {
        String(localized: "feedback.detail.submitted", bundle: #bundle)
    }

    // MARK: - Form Fields

    public static var formTitle: String {
        String(localized: "feedback.form.title", bundle: #bundle)
    }

    public static var formTitlePlaceholder: String {
        String(localized: "feedback.form.title.placeholder", bundle: #bundle)
    }

    public static var formDescription: String {
        String(localized: "feedback.form.description", bundle: #bundle)
    }

    public static var formDescriptionPlaceholder: String {
        String(localized: "feedback.form.description.placeholder", bundle: #bundle)
    }

    public static var formCategory: String {
        String(localized: "feedback.form.category", bundle: #bundle)
    }

    public static var formEmail: String {
        String(localized: "feedback.form.email", bundle: #bundle)
    }

    public static var formEmailPlaceholder: String {
        String(localized: "feedback.form.email.placeholder", bundle: #bundle)
    }

    public static var formEmailFooter: String {
        String(localized: "feedback.form.email.footer", bundle: #bundle)
    }

    // MARK: - Buttons

    public static var cancelButton: String {
        String(localized: "button.cancel", bundle: #bundle)
    }

    public static var sendButton: String {
        String(localized: "button.send", bundle: #bundle)
    }

    public static var voteButton: String {
        String(localized: "button.vote", bundle: #bundle)
    }

    public static var votedButton: String {
        String(localized: "button.voted", bundle: #bundle)
    }

    // MARK: - Toolbar

    public static var toolbarRefresh: String {
        String(localized: "toolbar.refresh", bundle: #bundle)
    }

    public static var toolbarSort: String {
        String(localized: "toolbar.sort", bundle: #bundle)
    }

    public static var toolbarFilter: String {
        String(localized: "toolbar.filter", bundle: #bundle)
    }

    public static var toolbarStatus: String {
        String(localized: "toolbar.status", bundle: #bundle)
    }

    // MARK: - Filter

    public static var filterAll: String {
        String(localized: "filter.all", bundle: #bundle)
    }

    // MARK: - Sort

    public static var sortVotes: String {
        String(localized: "sort.votes", bundle: #bundle)
    }

    public static var sortNewest: String {
        String(localized: "sort.newest", bundle: #bundle)
    }

    public static var sortOldest: String {
        String(localized: "sort.oldest", bundle: #bundle)
    }

    // MARK: - Comment Author

    public static var commentAuthorTeam: String {
        String(localized: "comment.author.team", bundle: #bundle)
    }

    public static var commentAuthorUser: String {
        String(localized: "comment.author.user", bundle: #bundle)
    }

    // MARK: - Status

    public static var statusPending: String {
        String(localized: "status.pending", bundle: #bundle)
    }

    public static var statusApproved: String {
        String(localized: "status.approved", bundle: #bundle)
    }

    public static var statusInProgress: String {
        String(localized: "status.inProgress", bundle: #bundle)
    }

    public static var statusTestFlight: String {
        String(localized: "status.testflight", bundle: #bundle)
    }

    public static var statusCompleted: String {
        String(localized: "status.completed", bundle: #bundle)
    }

    public static var statusRejected: String {
        String(localized: "status.rejected", bundle: #bundle)
    }

    // MARK: - Categories

    public static var categoryFeatureRequest: String {
        String(localized: "category.featureRequest", bundle: #bundle)
    }

    public static var categoryBugReport: String {
        String(localized: "category.bugReport", bundle: #bundle)
    }

    public static var categoryImprovement: String {
        String(localized: "category.improvement", bundle: #bundle)
    }

    public static var categoryOther: String {
        String(localized: "category.other", bundle: #bundle)
    }

    // MARK: - Errors

    public static var errorTitle: String {
        String(localized: "error.title", bundle: #bundle)
    }

    public static var errorOK: String {
        String(localized: "error.ok", bundle: #bundle)
    }

    public static var errorGeneric: String {
        String(localized: "error.generic", bundle: #bundle)
    }

    public static var errorInvalidApiKeyTitle: String {
        String(localized: "error.invalidApiKey.title", bundle: #bundle)
    }

    public static var errorInvalidApiKeyMessage: String {
        String(localized: "error.invalidApiKey.message", bundle: #bundle)
    }

    public static var errorFeedbackLimitTitle: String {
        String(localized: "error.feedbackLimit.title", bundle: #bundle)
    }

    public static var errorFeedbackLimitMessage: String {
        String(localized: "error.feedbackLimit.message", bundle: #bundle)
    }

    // MARK: - Feedback Submission Disabled

    public static var feedbackSubmissionDisabledTitle: String {
        String(localized: "feedback.submission.disabled.title", bundle: #bundle)
    }

    public static var feedbackSubmissionDisabledMessage: String {
        String(localized: "feedback.submission.disabled.message", bundle: #bundle)
    }

    // MARK: - Counts

    public static func votesCount(_ count: Int) -> String {
        String(localized: "votes.count", bundle: #bundle)
    }

    public static func commentsCount(_ count: Int) -> String {
        String(localized: "comments.count", bundle: #bundle)
    }
}
