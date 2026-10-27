import Foundation

/// Why a reader is reporting a feedback post or a comment.
///
/// The raw values are the wire contract. `ContentReportReason` in
/// `SwiftlyFeedbackServer/Sources/App/Models/ContentReportReason.swift` accepts
/// these same spellings.
public enum ContentReportReason: String, CaseIterable, Codable, Sendable, Hashable {
    case spam
    case harassment
    case hate
    case sexualContent = "sexual_content"
    case violence
    case other
}
