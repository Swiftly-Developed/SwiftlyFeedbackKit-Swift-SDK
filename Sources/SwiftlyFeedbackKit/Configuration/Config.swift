import Foundation

/// Configuration options for SwiftlyFeedback SDK.
///
/// Access via `SwiftlyFeedback.config`.
///
/// Example:
/// ```swift
/// SwiftlyFeedback.config.allowUndoVote = true
/// SwiftlyFeedback.config.showStatusBadge = false
/// ```
///
/// ## Localization
///
/// SwiftlyFeedback uses String Catalogs for localization.
/// To customize strings, add a `Localizable.xcstrings` file to your app
/// and override the keys from SwiftlyFeedbackKit's String Catalog.
///
/// Alternatively, you can export the SDK's strings for translation
/// using Xcode's localization export feature.
public final class SwiftlyFeedbackConfiguration: @unchecked Sendable {

    // MARK: - Feature Toggles

    /// Allow users to undo their votes. Default: `true`
    public var allowUndoVote: Bool = true

    /// Show the status badge on feedback items. Default: `true`
    public var showStatusBadge: Bool = true

    /// Show the category badge on feedback items. Default: `true`
    public var showCategoryBadge: Bool = true

    /// Expand descriptions in the feedback list. Default: `false`
    public var expandDescriptionInList: Bool = false

    /// Show the comment section on feedback details. Default: `true`
    public var showCommentSection: Bool = true

    /// Show vote count on feedback items. Default: `true`
    public var showVoteCount: Bool = true

    /// Show email field in submit feedback form. Default: `true`
    public var showEmailField: Bool = true

    // MARK: - User Identity

    /// The user's email address for vote notifications. Default: `nil`
    ///
    /// When set, this email is automatically used for vote notifications without showing
    /// a dialog. The user will be subscribed to status change notifications based on
    /// `voteNotificationDefaultOptIn`.
    ///
    /// Example:
    /// ```swift
    /// // Set user email once at configuration time
    /// SwiftlyFeedback.config.userEmail = "user@example.com"
    /// SwiftlyFeedback.config.voteNotificationDefaultOptIn = true
    /// ```
    public var userEmail: String? {
        didSet {
            if userEmail != oldValue {
                onUserEmailChanged?(userEmail)
            }
        }
    }

    /// Callback invoked when `userEmail` changes from within the SDK.
    ///
    /// Use this to sync the email back to your app's settings when the user
    /// provides their email through the vote dialog.
    ///
    /// Example:
    /// ```swift
    /// SwiftlyFeedback.config.onUserEmailChanged = { email in
    ///     // Save to your app's settings/UserDefaults
    ///     UserDefaults.standard.set(email ?? "", forKey: "userEmail")
    /// }
    /// ```
    public var onUserEmailChanged: ((String?) -> Void)?

    // MARK: - Voting Notifications

    /// Show email field in vote dialog for status change notifications. Default: `true`
    ///
    /// When enabled and `userEmail` is not set, users will see a dialog when voting
    /// that allows them to optionally provide an email address to receive notifications
    /// when the feedback status changes.
    ///
    /// When `userEmail` is already configured, no dialog is shown regardless of this setting.
    ///
    /// Example:
    /// ```swift
    /// // Disable vote notification email field
    /// SwiftlyFeedback.config.showVoteEmailField = false
    /// ```
    public var showVoteEmailField: Bool = true

    /// Default opt-in state for vote status notifications. Default: `false`
    ///
    /// When `true`, vote status notifications are enabled by default.
    /// - If `userEmail` is set, votes automatically include notification opt-in.
    /// - If `userEmail` is not set and dialog is shown, the toggle starts enabled.
    public var voteNotificationDefaultOptIn: Bool = false

    // MARK: - Mailing List

    /// Show an opt-in checkbox for subscribing to the project's mailing list. Default: `true`
    ///
    /// When enabled and the user provides an email (via the submit form or vote dialog),
    /// a toggle is shown allowing them to opt in to the project's mailing list.
    /// The server silently ignores the flag if no email campaign integration is configured.
    public var showMailingListOptIn: Bool = true

    /// Default state of the mailing list opt-in toggle. Default: `false`
    ///
    /// When `true`, the mailing list toggle starts enabled by default.
    public var mailingListDefaultOptIn: Bool = false

    // MARK: - Permissions

    /// Allow users to submit new feedback. Default: `true`
    ///
    /// When set to `false`, the add button will show an alert with `feedbackSubmissionDisabledMessage`
    /// instead of opening the submission form. Use this to restrict feedback submission to paying users.
    ///
    /// Example:
    /// ```swift
    /// // Disable feedback submission for free users
    /// SwiftlyFeedback.config.allowFeedbackSubmission = user.isPro
    /// SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro to submit feature requests!"
    /// ```
    public var allowFeedbackSubmission: Bool = true

    /// Message shown when feedback submission is disabled. Default: `nil` (uses system default)
    ///
    /// When `allowFeedbackSubmission` is `false` and the user taps the add button,
    /// this message is displayed in an alert dialog.
    public var feedbackSubmissionDisabledMessage: String?

    // MARK: - Analytics

    /// Enable automatic view tracking for SDK views. Default: `true`
    public var enableAutomaticViewTracking: Bool = true

    // MARK: - Logging

    /// Enable SDK logging output. Default: `true`
    ///
    /// When set to `false`, the SDK will not output any debug messages to the console.
    /// This is useful to prevent the Xcode debug console from being cluttered with SDK logs.
    ///
    /// Example:
    /// ```swift
    /// // Disable SDK logging
    /// SwiftlyFeedback.config.loggingEnabled = false
    /// ```
    public var loggingEnabled: Bool = true

    // MARK: - Buttons Configuration

    /// Button configuration options
    public var buttons = ButtonsConfiguration()

    internal init() {}
}

// MARK: - Buttons Configuration

public final class ButtonsConfiguration: @unchecked Sendable {
    /// Add feedback button configuration
    public var addButton = AddButtonConfiguration()

    /// Segmented control configuration
    public var segmentedControl = SegmentedControlConfiguration()

    internal init() {}
}

public final class AddButtonConfiguration: @unchecked Sendable {
    /// Bottom padding for the add button. Default: `16`
    public var bottomPadding: CGFloat = 16

    /// Whether to display the add button. Default: `true`
    public var display: Bool = true

    internal init() {}
}

public final class SegmentedControlConfiguration: @unchecked Sendable {
    /// Whether to display the segmented control. Default: `true`
    public var display: Bool = true

    internal init() {}
}
