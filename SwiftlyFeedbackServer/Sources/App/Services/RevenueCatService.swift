import Vapor
import Fluent
import Crypto

struct RevenueCatService {
    private let client: Client
    private let apiKey: String
    private let webhookSecret: String
    private let baseURL = "https://api.revenuecat.com/v1"

    // Pro entitlement ID configured in RevenueCat dashboard
    static let proEntitlementID = "Swiftly Pro"

    // Team entitlement ID configured in RevenueCat dashboard
    static let teamEntitlementID = "Swiftly Team"

    init(client: Client) {
        self.client = client
        self.apiKey = Environment.get("REVENUECAT_API_KEY") ?? ""
        self.webhookSecret = Environment.get("REVENUECAT_WEBHOOK_SECRET") ?? ""
    }

    // MARK: - Webhook Signature Verification

    /// Verify the webhook signature from RevenueCat
    /// RevenueCat uses HMAC-SHA256 for webhook signatures
    func verifyWebhookSignature(payload: Data, signature: String) -> Bool {
        guard !webhookSecret.isEmpty else {
            // In development, skip verification if no secret is configured
            return true
        }

        let key = SymmetricKey(data: Data(webhookSecret.utf8))
        let expectedSignature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let expectedSignatureString = Data(expectedSignature).base64EncodedString()

        return signature == expectedSignatureString
    }

    // MARK: - RevenueCat API

    /// Fetch subscriber information from RevenueCat API
    func getSubscriber(appUserId: String) async throws -> RevenueCatSubscriberResponse {
        guard !apiKey.isEmpty else {
            throw Abort(.internalServerError, reason: "RevenueCat API key not configured")
        }

        let encodedUserId = appUserId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appUserId
        let url = URI(string: "\(baseURL)/subscribers/\(encodedUserId)")

        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: "Bearer \(apiKey)")
            req.headers.add(name: .contentType, value: "application/json")
        }

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to fetch subscriber from RevenueCat: \(response.status)")
        }

        return try response.content.decode(RevenueCatSubscriberResponse.self)
    }

    // MARK: - Entitlement Mapping

    /// Map RevenueCat entitlements to SubscriptionTier
    func mapEntitlementsToTier(entitlements: [String: RevenueCatSubscriberResponse.Subscriber.Entitlement]) -> SubscriptionTier {
        // Check Team first (higher tier)
        if let teamEntitlement = entitlements[Self.teamEntitlementID] {
            // Check if not expired
            if let expiresDateString = teamEntitlement.expiresDate,
               let expiresDate = ISO8601DateFormatter().date(from: expiresDateString),
               expiresDate > Date() {
                return .team
            }
            // If no expiration date, it's a lifetime subscription
            if teamEntitlement.expiresDate == nil {
                return .team
            }
        }

        // Check for Pro entitlement
        if let proEntitlement = entitlements[Self.proEntitlementID] {
            // Check if not expired
            if let expiresDateString = proEntitlement.expiresDate,
               let expiresDate = ISO8601DateFormatter().date(from: expiresDateString),
               expiresDate > Date() {
                return .pro
            }
            // If no expiration date, it's a lifetime subscription
            if proEntitlement.expiresDate == nil {
                return .pro
            }
        }

        return .free
    }

    /// Get subscription status from entitlements
    func getSubscriptionStatus(entitlements: [String: RevenueCatSubscriberResponse.Subscriber.Entitlement]) -> SubscriptionStatus? {
        // Check Team first (higher tier), then Pro
        let entitlement = entitlements[Self.teamEntitlementID] ?? entitlements[Self.proEntitlementID]
        guard let entitlement else {
            return nil
        }

        if let expiresDateString = entitlement.expiresDate,
           let expiresDate = ISO8601DateFormatter().date(from: expiresDateString) {
            if expiresDate > Date() {
                return .active
            } else {
                return .expired
            }
        }

        // No expiration = lifetime/active
        return .active
    }

    /// Get expiration date from entitlements
    func getExpirationDate(entitlements: [String: RevenueCatSubscriberResponse.Subscriber.Entitlement]) -> Date? {
        // Check Team first (higher tier), then Pro
        let entitlement = entitlements[Self.teamEntitlementID] ?? entitlements[Self.proEntitlementID]
        guard let expiresDateString = entitlement?.expiresDate else {
            return nil
        }

        return ISO8601DateFormatter().date(from: expiresDateString)
    }

    /// Get product ID from entitlements
    func getProductId(entitlements: [String: RevenueCatSubscriberResponse.Subscriber.Entitlement]) -> String? {
        // Check Team first (higher tier), then Pro
        return entitlements[Self.teamEntitlementID]?.productIdentifier ?? entitlements[Self.proEntitlementID]?.productIdentifier
    }

    /// Determine tier from product ID
    func tierFromProductId(_ productId: String?) -> SubscriptionTier {
        guard let productId else { return .free }
        if productId.contains("team") {
            return .team
        } else if productId.contains("pro") {
            return .pro
        }
        return .free
    }

    // MARK: - Webhook Event Processing

    /// Process a webhook event and update user subscription
    func processWebhookEvent(
        event: RevenueCatWebhookPayload.RevenueCatEvent,
        on database: Database
    ) async throws {
        // Find user by RevenueCat app user ID
        guard let user = try await User.query(on: database)
            .filter(\.$revenueCatAppUserId == event.appUserId)
            .first() else {
            // User not found - they may not have linked their account yet
            // This is not an error, just log and return
            return
        }

        // Update user based on event type
        switch event.type {
        case "INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION":
            // Determine tier from product ID (team vs pro)
            user.subscriptionTier = tierFromProductId(event.productId)
            user.subscriptionStatus = SubscriptionStatus.active
            user.subscriptionProductId = event.productId

            if let expirationMs = event.expirationAtMs {
                user.subscriptionExpiresAt = Date(timeIntervalSince1970: TimeInterval(expirationMs) / 1000)
            }

        case "EXPIRATION":
            user.subscriptionTier = SubscriptionTier.free
            user.subscriptionStatus = SubscriptionStatus.expired

        case "CANCELLATION":
            // User cancelled but may still have access until expiration
            user.subscriptionStatus = SubscriptionStatus.cancelled
            // Keep tier until actual expiration

        case "BILLING_ISSUE":
            user.subscriptionStatus = SubscriptionStatus.gracePeriod

        case "PRODUCT_CHANGE":
            // Plan change (monthly <-> yearly, or pro <-> team)
            user.subscriptionTier = tierFromProductId(event.productId)
            user.subscriptionProductId = event.productId
            if let expirationMs = event.expirationAtMs {
                user.subscriptionExpiresAt = Date(timeIntervalSince1970: TimeInterval(expirationMs) / 1000)
            }

        default:
            // Unknown event type, ignore
            return
        }

        user.subscriptionUpdatedAt = Date()
        try await user.save(on: database)
    }
}

// MARK: - Request Extension

extension Request {
    var revenueCatService: RevenueCatService {
        RevenueCatService(client: self.client)
    }
}
