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

    // MARK: - Vote Dialog

    public static var voteDialogTitle: String {
        String(localized: "vote.dialog.title", bundle: #bundle)
    }

    public static var voteDialogEmailHeader: String {
        String(localized: "vote.dialog.email.header", bundle: #bundle)
    }

    public static var voteDialogEmailPlaceholder: String {
        String(localized: "vote.dialog.email.placeholder", bundle: #bundle)
    }

    public static var voteDialogEmailFooter: String {
        String(localized: "vote.dialog.email.footer", bundle: #bundle)
    }

    public static var voteDialogNotifyToggle: String {
        String(localized: "vote.dialog.notify.toggle", bundle: #bundle)
    }

    public static var voteDialogNotifyDescription: String {
        String(localized: "vote.dialog.notify.description", bundle: #bundle)
    }

    public static var voteDialogSkip: String {
        String(localized: "vote.dialog.skip", bundle: #bundle)
    }

    public static var voteDialogSubmit: String {
        String(localized: "vote.dialog.submit", bundle: #bundle)
    }

    // MARK: - Mailing List

    public static var mailingListOptIn: String {
        String(localized: "mailingList.optIn", bundle: #bundle)
    }

    public static var mailingListOptInDescription: String {
        String(localized: "mailingList.optIn.description", bundle: #bundle)
    }

    public static var mailingListOperational: String {
        String(localized: "mailingList.operational", bundle: #bundle)
    }

    public static var mailingListMarketing: String {
        String(localized: "mailingList.marketing", bundle: #bundle)
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

    public static var sortComments: String {
        String(localized: "sort.comments", bundle: #bundle)
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

    // MARK: - Rejection Reason

    public static var rejectionReasonTitle: String {
        String(localized: "rejection.reason.title", bundle: #bundle)
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

    // MARK: - Accessibility

    static func accessibilityVoteCount(_ count: Int) -> String {
        let format = String(localized: "accessibility.vote.count", bundle: #bundle)
        return String(format: format, count)
    }

    static var accessibilityVoteHint: String {
        String(localized: "accessibility.vote.hint", bundle: #bundle)
    }

    static var accessibilityUnvoteHint: String {
        String(localized: "accessibility.unvote.hint", bundle: #bundle)
    }

    static var accessibilityVotingClosed: String {
        String(localized: "accessibility.voting.closed", bundle: #bundle)
    }

    static var accessibilityVoted: String {
        String(localized: "accessibility.voted", bundle: #bundle)
    }

    static var accessibilityNotVoted: String {
        String(localized: "accessibility.notVoted", bundle: #bundle)
    }

    static func accessibilityStatus(_ status: String) -> String {
        let format = String(localized: "accessibility.status", bundle: #bundle)
        return String(format: format, status)
    }

    static func accessibilityCategory(_ category: String) -> String {
        let format = String(localized: "accessibility.category", bundle: #bundle)
        return String(format: format, category)
    }

    static func accessibilityCommentCount(_ count: Int) -> String {
        let format = String(localized: "accessibility.comment.count", bundle: #bundle)
        return String(format: format, count)
    }

    static var accessibilityViewDetails: String {
        String(localized: "accessibility.viewDetails", bundle: #bundle)
    }

    static var accessibilityLoadingFeedback: String {
        String(localized: "accessibility.loading.feedback", bundle: #bundle)
    }

    static var accessibilityLoadingComments: String {
        String(localized: "accessibility.loading.comments", bundle: #bundle)
    }

    static func accessibilityRejectionReason(_ reason: String) -> String {
        let format = String(localized: "accessibility.rejectionReason", bundle: #bundle)
        return String(format: format, reason)
    }

    static var accessibilityAddComment: String {
        String(localized: "accessibility.addComment", bundle: #bundle)
    }

    static var accessibilityPostComment: String {
        String(localized: "accessibility.postComment", bundle: #bundle)
    }

    static var accessibilityFormRequired: String {
        String(localized: "accessibility.form.required", bundle: #bundle)
    }

    static var accessibilityFormOptional: String {
        String(localized: "accessibility.form.optional", bundle: #bundle)
    }

    static var accessibilityFormDescriptionHint: String {
        String(localized: "accessibility.form.description.hint", bundle: #bundle)
    }

    static var accessibilitySubmitHint: String {
        String(localized: "accessibility.submit.hint", bundle: #bundle)
    }

    static var accessibilitySubmitDisabledHint: String {
        String(localized: "accessibility.submit.disabled.hint", bundle: #bundle)
    }

    static var accessibilitySubmitting: String {
        String(localized: "accessibility.submitting", bundle: #bundle)
    }
}
