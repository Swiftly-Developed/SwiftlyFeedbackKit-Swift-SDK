import Foundation

/// Machine-readable moderation tokens the server puts in an error `reason`.
enum ModerationWireToken {
    /// Matches `ObjectionableContentFilter.rejectionReason` in
    /// `SwiftlyFeedbackServer/Sources/App/Services/ObjectionableContentFilter.swift`.
    static let objectionableContent = "objectionable_content"
}
