import Fluent
import Vapor

/// Represents a user from the SDK (not an admin user).
/// Tracks anonymous users and their MRR for analytics.
final class SDKUser: Model, Content, @unchecked Sendable {
    static let schema = "sdk_users"

    @ID(key: .id)
    var id: UUID?

    /// The user identifier from the SDK (can be iCloud-based, local UUID, or custom foreign key)
    @Field(key: "user_id")
    var userId: String

    /// The project this user belongs to
    @Parent(key: "project_id")
    var project: Project

    /// Monthly Recurring Revenue attributed to this user (in cents or smallest currency unit)
    /// Null means no revenue tracking for this user
    @OptionalField(key: "mrr")
    var mrr: Double?

    /// First time this user was seen
    @Timestamp(key: "first_seen_at", on: .create)
    var firstSeenAt: Date?

    /// Last time this user was active (updated on any API call)
    @Timestamp(key: "last_seen_at", on: .update)
    var lastSeenAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: String,
        projectId: UUID,
        mrr: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.$project.id = projectId
        self.mrr = mrr
    }
}
