//
//  SubscriptionService.swift
//  SwiftlyFeedbackAdmin
//
//  Created by Ben Van Aken on 04/01/2026.
//

import Foundation
import RevenueCat

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

// MARK: - Subscription Service

/// Service responsible for managing subscriptions via RevenueCat.
@MainActor
@Observable
final class SubscriptionService: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = SubscriptionService()

    // MARK: - Configuration

    /// RevenueCat public API key - Replace with your actual key from RevenueCat dashboard
    static let revenueCatAPIKey = "appl_qwlqUlehsPfFfhvmaWLAqfEKMGs"

    /// Entitlement identifier for Pro tier (must match RevenueCat dashboard)
    static let proEntitlementID = "Swiftly Pro"

    /// Product identifiers
    enum ProductID: String, CaseIterable {
        case proMonthly = "swiftlyfeedback.pro.monthly"
        case proYearly = "swiftlyfeedback.pro.yearly"
        case teamMonthly = "swiftlyfeedback.team.monthly"
        case teamYearly = "swiftlyfeedback.team.yearly"
    }

    // MARK: - State

    /// Whether the service is currently loading data
    private(set) var isLoading = false

    /// Error message if an operation failed
    private(set) var errorMessage: String?

    /// Whether an error should be shown
    var showError = false

    /// Current customer info from RevenueCat
    private(set) var customerInfo: CustomerInfo?

    /// Available offerings from RevenueCat
    private(set) var offerings: Offerings?

    // MARK: - Computed Properties - Tier

    /// The user's current subscription tier based on RevenueCat entitlements
    var currentTier: SubscriptionTier {
        guard let customerInfo else { return .free }

        // Check for Pro entitlement
        if customerInfo.entitlements[Self.proEntitlementID]?.isActive == true {
            return .pro
        }

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
        customerInfo?.entitlements[Self.proEntitlementID]?.expirationDate
    }

    /// Whether the subscription will renew
    var willRenew: Bool {
        customerInfo?.entitlements[Self.proEntitlementID]?.willRenew ?? false
    }

    /// Display name for the current subscription status
    var subscriptionStatusText: String {
        currentTier.displayName
    }

    // MARK: - Initialization

    private init() {
        AppLogger.subscription.info("SubscriptionService initialized")
    }

    // MARK: - Configuration

    /// Configure the subscription service. Call this once at app launch.
    func configure(userId: UUID? = nil) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey)
        AppLogger.subscription.info("RevenueCat configured")

        if let userId {
            Task {
                await login(userId: userId)
            }
        }
    }

    // MARK: - Authentication

    /// Login with a user ID (call after user authentication)
    func login(userId: UUID) async {
        AppLogger.subscription.info("Logging in to RevenueCat with user ID: \(userId)")

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId.uuidString)
            self.customerInfo = customerInfo
            AppLogger.subscription.info("RevenueCat login successful, tier: \(currentTier.displayName)")

            // Sync with server
            await syncWithServer()
        } catch {
            AppLogger.subscription.error("RevenueCat login failed: \(error)")
        }
    }

    /// Logout (call after user logout)
    func logout() async {
        AppLogger.subscription.info("Logging out from RevenueCat")

        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            AppLogger.subscription.info("RevenueCat logout successful")
        } catch {
            AppLogger.subscription.error("RevenueCat logout failed: \(error)")
        }
    }

    // MARK: - Data Fetching

    /// Fetch the current customer info
    func fetchCustomerInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.customerInfo()
            AppLogger.subscription.info("Fetched customer info, tier: \(currentTier.displayName)")
        } catch {
            AppLogger.subscription.error("Failed to fetch customer info: \(error)")
            showError(message: error.localizedDescription)
        }
    }

    /// Fetch available offerings
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await Purchases.shared.offerings()
            AppLogger.subscription.info("Fetched offerings: \(offerings?.current?.availablePackages.count ?? 0) packages")
        } catch {
            AppLogger.subscription.error("Failed to fetch offerings: \(error)")
            showError(message: error.localizedDescription)
        }
    }

    // MARK: - Purchases

    /// Purchase a subscription package
    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        AppLogger.subscription.info("Starting purchase for package: \(package.identifier)")

        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            self.customerInfo = customerInfo
            AppLogger.subscription.info("Purchase successful, tier: \(currentTier.displayName)")

            // Sync with server after purchase
            await syncWithServer()
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError {
                AppLogger.subscription.info("Purchase cancelled by user")
                throw SubscriptionError.purchaseCancelled
            }
            AppLogger.subscription.error("Purchase failed: \(error)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        } catch {
            AppLogger.subscription.error("Purchase failed: \(error)")
            throw SubscriptionError.purchaseFailed(error.localizedDescription)
        }
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        AppLogger.subscription.info("Restoring purchases")

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            AppLogger.subscription.info("Purchases restored, tier: \(currentTier.displayName)")

            // Sync with server after restore
            await syncWithServer()
        } catch {
            AppLogger.subscription.error("Restore failed: \(error)")
            throw error
        }
    }

    // MARK: - Server Sync

    /// Sync subscription status with the server
    private func syncWithServer() async {
        AppLogger.subscription.info("Syncing subscription with server")

        do {
            // Call the server sync endpoint
            let _: EmptyResponse = try await AdminAPIClient.shared.post(
                path: "auth/subscription/sync",
                body: ["revenuecat_app_user_id": Purchases.shared.appUserID],
                requiresAuth: true
            )
            AppLogger.subscription.info("Subscription synced with server")
        } catch {
            AppLogger.subscription.error("Failed to sync subscription with server: \(error)")
            // Don't throw - this is a best-effort sync
        }
    }

    // MARK: - Entitlement Checking

    /// Check if the user has access to a specific entitlement
    func hasEntitlement(_ entitlementId: String) -> Bool {
        customerInfo?.entitlements[entitlementId]?.isActive == true
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

// MARK: - Empty Response

private struct EmptyResponse: Codable {}

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
