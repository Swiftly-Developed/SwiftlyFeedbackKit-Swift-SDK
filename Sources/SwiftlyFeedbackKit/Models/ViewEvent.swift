import Foundation

/// Predefined view events that are automatically tracked by the SDK.
///
/// The metrics surface spells the same three names as ``PredefinedEventName``; the two are
/// bridged by exhaustive switches on that type, so neither list can gain a member without
/// the other. `CaseIterable` is what lets the two raw-value sets be compared.
public enum PredefinedView: String, Sendable, CaseIterable {
    /// Feedback list view
    case feedbackList = "feedback_list"
    /// Feedback detail view
    case feedbackDetail = "feedback_detail"
    /// Submit feedback view
    case submitFeedback = "submit_feedback"
}

/// Response from tracking a view event, and the row shape of the metrics event feed.
public struct ViewEventResponse: Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let eventName: String
    public let userId: String
    public let properties: [String: String]?
    public let createdAt: Date?

    public init(
        id: UUID,
        eventName: String,
        userId: String,
        properties: [String: String]? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.eventName = eventName
        self.userId = userId
        self.properties = properties
        self.createdAt = createdAt
    }
}
