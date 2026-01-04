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
