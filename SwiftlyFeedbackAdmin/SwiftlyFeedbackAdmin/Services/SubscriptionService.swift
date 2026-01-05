//
//  SubscriptionService.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 04/01/2026.
//

import Foundation

// MARK: - Subscription Tier

/// Represents the user's subscription tier
enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case team = "team"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }

    /// Maximum number of projects allowed (nil = unlimited)
    var maxProjects: Int? {
        switch self {
        case .free: return 1
        case .pro: return 2
        case .team: return nil
        }
    }

    /// Maximum feedback items per project (nil = unlimited)
    var maxFeedbackPerProject: Int? {
        switch self {
        case .free: return 10
        case .pro: return nil
        case .team: return nil
        }
    }

    /// Whether the tier allows inviting team members
    var canInviteMembers: Bool {
        self == .team
    }

    /// Whether the tier has access to integrations (Slack, GitHub, Email)
    var hasIntegrations: Bool {
        self == .team
    }

    /// Whether the tier has advanced analytics (MRR, detailed insights)
    var hasAdvancedAnalytics: Bool {
        self != .free
    }

    /// Whether the tier has configurable statuses
    var hasConfigurableStatuses: Bool {
        self != .free
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

// MARK: - Subscription Service (Stub)

/// Service responsible for managing subscriptions.
/// NOTE: RevenueCat integration is not yet complete. This is a stub that returns free tier.
/// TODO: Re-enable RevenueCat when the SDK is properly configured.
@MainActor
@Observable
final class SubscriptionService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SubscriptionService()

    // MARK: - Configuration

    /// Entitlement identifiers (for future RevenueCat integration)
    static let proEntitlementID = "Swiftly Pro"
    static let teamEntitlementID = "Swiftly Team"

    /// Product identifiers (for future RevenueCat integration)
    enum ProductID: String, CaseIterable {
        case monthly = "monthly"
        case yearly = "yearly"
        case monthlyTeam = "monthlyTeam"
        case yearlyTeam = "yearlyTeam"
    }

    // MARK: - Published State

    /// Whether the service is currently loading data
    private(set) var isLoading = false

    /// Error message if an operation failed
    private(set) var errorMessage: String?

    /// Whether an error should be shown
    var showError = false

    // MARK: - Computed Properties - Tier

    /// The user's current subscription tier
    /// NOTE: Always returns .free until RevenueCat is integrated
    var currentTier: SubscriptionTier {
        // TODO: Implement actual subscription checking with RevenueCat
        return .free
    }

    /// Whether the user has an active Team subscription
    var isTeamSubscriber: Bool {
        currentTier == .team
    }

    /// Whether the user has an active Pro subscription (or higher)
    var isProSubscriber: Bool {
        currentTier == .pro || currentTier == .team
    }

    /// Whether the user has any paid subscription
    var isPaidSubscriber: Bool {
        isProSubscriber || isTeamSubscriber
    }

    /// The expiration date of the active subscription
    var subscriptionExpirationDate: Date? {
        // TODO: Implement with RevenueCat
        return nil
    }

    /// Whether the subscription will renew
    var willRenew: Bool {
        // TODO: Implement with RevenueCat
        return false
    }

    /// Display name for the current subscription status
    var subscriptionStatusText: String {
        switch currentTier {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        case .team:
            return "Team"
        }
    }

    // MARK: - Initialization

    private init() {
        AppLogger.subscription.info("SubscriptionService initialized (stub mode)")
    }

    // MARK: - Stub Methods

    /// Configure the subscription service. Call this once at app launch.
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func configure(userId: UUID? = nil) {
        AppLogger.subscription.info("🔧 SubscriptionService.configure() called (stub - RevenueCat not integrated)")
    }

    /// Login with a user ID (call after user authentication)
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func login(userId: UUID) async {
        AppLogger.subscription.info("🔐 SubscriptionService.login() called (stub - RevenueCat not integrated)")
    }

    /// Logout (call after user logout)
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func logout() async {
        AppLogger.subscription.info("🚪 SubscriptionService.logout() called (stub - RevenueCat not integrated)")
    }

    /// Fetch the current customer info
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func fetchCustomerInfo() async {
        AppLogger.subscription.info("📊 SubscriptionService.fetchCustomerInfo() called (stub)")
    }

    /// Fetch available offerings
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func fetchOfferings() async {
        AppLogger.subscription.info("📦 SubscriptionService.fetchOfferings() called (stub)")
    }

    /// Restore previous purchases
    /// NOTE: This is a stub - RevenueCat is not yet integrated.
    func restorePurchases() async throws {
        AppLogger.subscription.info("🔄 SubscriptionService.restorePurchases() called (stub)")
        // In stub mode, just show a message that there's nothing to restore
        throw SubscriptionError.notImplemented
    }

    // MARK: - Entitlement Checking

    /// Check if the user has access to a specific entitlement
    func hasEntitlement(_ entitlementId: String) -> Bool {
        // TODO: Implement with RevenueCat
        return false
    }

    /// Check if the user has pro access (Pro or Team tier)
    func hasProAccess() -> Bool {
        isProSubscriber
    }

    /// Check if the user has team access
    func hasTeamAccess() -> Bool {
        isTeamSubscriber
    }

    /// Check if the user's tier meets the required tier
    func hasTierAccess(_ requiredTier: SubscriptionTier) -> Bool {
        currentTier.meetsRequirement(requiredTier)
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case purchaseCancelled
    case noProductsAvailable
    case purchaseFailed(String)
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .noProductsAvailable:
            return "No subscription products are available"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .notImplemented:
            return "Subscriptions are not yet available. Coming soon!"
        }
    }
}
