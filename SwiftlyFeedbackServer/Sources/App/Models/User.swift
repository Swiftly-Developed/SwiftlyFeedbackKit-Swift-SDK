import Fluent
import Vapor

// MARK: - Subscription Enums

enum SubscriptionTier: String, Codable, CaseIterable, Sendable {
    case free
    case pro
    case team

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }

    /// Maximum number of projects allowed for this tier. nil = unlimited
    var maxProjects: Int? {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .team: return nil
        }
    }

    /// Maximum feedback items per project. nil = unlimited
    var maxFeedbackPerProject: Int? {
        switch self {
        case .free: return 10
        case .pro, .team: return nil
        }
    }

    /// Check if this tier meets the requirement of another tier
    func meetsRequirement(_ required: SubscriptionTier) -> Bool {
        switch required {
        case .free: return true
        case .pro: return self == .pro || self == .team
        case .team: return self == .team
        }
    }
}

enum SubscriptionStatus: String, Codable, CaseIterable, Sendable {
    case active
    case expired
    case cancelled
    case gracePeriod = "grace_period"
    case paused

    var isActive: Bool {
        self == .active || self == .gracePeriod
    }
}

// MARK: - User Model

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "name")
    var name: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "is_admin")
    var isAdmin: Bool

    @Field(key: "is_email_verified")
    var isEmailVerified: Bool

    @Field(key: "notify_new_feedback")
    var notifyNewFeedback: Bool

    @Field(key: "notify_new_comments")
    var notifyNewComments: Bool

    // Subscription fields
    @Field(key: "subscription_tier")
    var subscriptionTier: SubscriptionTier

    @OptionalField(key: "subscription_status")
    var subscriptionStatus: SubscriptionStatus?

    @OptionalField(key: "subscription_product_id")
    var subscriptionProductId: String?

    @OptionalField(key: "subscription_expires_at")
    var subscriptionExpiresAt: Date?

    @OptionalField(key: "revenuecat_app_user_id")
    var revenueCatAppUserId: String?

    @OptionalField(key: "subscription_updated_at")
    var subscriptionUpdatedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$owner)
    var ownedProjects: [Project]

    @Siblings(through: ProjectMember.self, from: \.$user, to: \.$project)
    var memberProjects: [Project]

    init() {}

    init(
        id: UUID? = nil,
        email: String,
        name: String,
        passwordHash: String,
        isAdmin: Bool = false,
        isEmailVerified: Bool = false,
        notifyNewFeedback: Bool = true,
        notifyNewComments: Bool = true,
        subscriptionTier: SubscriptionTier = .free
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
        self.isEmailVerified = isEmailVerified
        self.notifyNewFeedback = notifyNewFeedback
        self.notifyNewComments = notifyNewComments
        self.subscriptionTier = subscriptionTier
    }
}

extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, Field<String>> {
        \User.$email
    }
    static var passwordHashKey: KeyPath<User, Field<String>> {
        \User.$passwordHash
    }

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension User {
    func generateToken() throws -> UserToken {
        try UserToken(
            value: [UInt8].random(count: 32).base64,
            userID: self.requireID()
        )
    }
}

extension User {
    struct Public: Content {
        let id: UUID
        let email: String
        let name: String
        let isAdmin: Bool
        let isEmailVerified: Bool
        let notifyNewFeedback: Bool
        let notifyNewComments: Bool
        let subscriptionTier: SubscriptionTier
        let subscriptionStatus: SubscriptionStatus?
        let subscriptionExpiresAt: Date?
        let createdAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, email, name
            case isAdmin = "is_admin"
            case isEmailVerified = "is_email_verified"
            case notifyNewFeedback = "notify_new_feedback"
            case notifyNewComments = "notify_new_comments"
            case subscriptionTier = "subscription_tier"
            case subscriptionStatus = "subscription_status"
            case subscriptionExpiresAt = "subscription_expires_at"
            case createdAt = "created_at"
        }
    }

    func asPublic() throws -> Public {
        Public(
            id: try requireID(),
            email: email,
            name: name,
            isAdmin: isAdmin,
            isEmailVerified: isEmailVerified,
            notifyNewFeedback: notifyNewFeedback,
            notifyNewComments: notifyNewComments,
            subscriptionTier: subscriptionTier,
            subscriptionStatus: subscriptionStatus,
            subscriptionExpiresAt: subscriptionExpiresAt,
            createdAt: createdAt
        )
    }
}
