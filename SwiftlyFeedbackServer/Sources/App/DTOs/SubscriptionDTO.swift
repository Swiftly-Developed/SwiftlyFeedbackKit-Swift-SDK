import Vapor

// MARK: - Subscription Info Response

struct SubscriptionInfoDTO: Content {
    let tier: SubscriptionTier
    let status: SubscriptionStatus?
    let productId: String?
    let expiresAt: Date?
    let limits: SubscriptionLimitsDTO

    enum CodingKeys: String, CodingKey {
        case tier, status, limits
        case productId = "product_id"
        case expiresAt = "expires_at"
    }
}

struct SubscriptionLimitsDTO: Content {
    let maxProjects: Int?
    let maxFeedbackPerProject: Int?
    let currentProjectCount: Int
    let canCreateProject: Bool

    enum CodingKeys: String, CodingKey {
        case maxProjects = "max_projects"
        case maxFeedbackPerProject = "max_feedback_per_project"
        case currentProjectCount = "current_project_count"
        case canCreateProject = "can_create_project"
    }
}

// MARK: - Payment Required Error Response

struct PaymentRequiredDTO: Content {
    let reason: String
    let currentTier: SubscriptionTier
    let requiredTier: SubscriptionTier
    let limit: Int?
    let current: Int?

    enum CodingKeys: String, CodingKey {
        case reason, limit, current
        case currentTier = "current_tier"
        case requiredTier = "required_tier"
    }
}

// MARK: - Sync Request

struct SyncSubscriptionDTO: Content {
    let revenueCatAppUserId: String?

    enum CodingKeys: String, CodingKey {
        case revenueCatAppUserId = "revenuecat_app_user_id"
    }
}

// MARK: - RevenueCat Webhook Payload

struct RevenueCatWebhookPayload: Content {
    let event: RevenueCatEvent

    struct RevenueCatEvent: Content {
        let type: String
        let appUserId: String
        let productId: String?
        let expirationAtMs: Int64?
        let purchasedAtMs: Int64?

        enum CodingKeys: String, CodingKey {
            case type
            case appUserId = "app_user_id"
            case productId = "product_id"
            case expirationAtMs = "expiration_at_ms"
            case purchasedAtMs = "purchased_at_ms"
        }
    }
}

// MARK: - RevenueCat API Response

struct RevenueCatSubscriberResponse: Content {
    let subscriber: Subscriber

    struct Subscriber: Content {
        let entitlements: [String: Entitlement]

        struct Entitlement: Content {
            let productIdentifier: String
            let expiresDate: String?
            let purchaseDate: String?

            enum CodingKeys: String, CodingKey {
                case productIdentifier = "product_identifier"
                case expiresDate = "expires_date"
                case purchaseDate = "purchase_date"
            }
        }
    }
}
