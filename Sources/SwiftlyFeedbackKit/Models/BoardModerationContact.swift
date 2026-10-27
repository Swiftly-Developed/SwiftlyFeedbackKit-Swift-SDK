import Foundation

/// The published address readers use to report objectionable board content.
public enum BoardModerationContact {
    /// Shown on the feedback board unless the host sets
    /// `SwiftlyFeedbackConfiguration.moderationContactEmail`.
    ///
    /// FeedbackKit's moderation alias, which forwards to the company mailbox.
    public static let defaultAddress = "moderation@getfeedbackkit.com"
}
