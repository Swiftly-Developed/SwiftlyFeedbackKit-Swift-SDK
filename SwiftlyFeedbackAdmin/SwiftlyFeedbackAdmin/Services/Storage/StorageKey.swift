import Foundation

/// All persistent storage keys used by the Admin app.
/// Keys are either environment-scoped or have a fixed scope.
enum StorageKey: String, CaseIterable, Sendable {
    // MARK: - Authentication
    /// Bearer token for API authentication (environment-specific)
    case authToken = "authToken"

    /// Whether to keep the user signed in (save credentials for auto re-login)
    case keepMeSignedIn = "keepMeSignedIn"

    /// Saved email for auto re-login (environment-specific)
    case savedEmail = "savedEmail"

    /// Saved password for auto re-login (environment-specific, stored securely in Keychain)
    case savedPassword = "savedPassword"

    // MARK: - Onboarding
    /// Whether the user has completed onboarding (environment-specific)
    case hasCompletedOnboarding = "hasCompletedOnboarding"

    // MARK: - UI Preferences
    /// Feedback list view mode: list, table, or grid (environment-specific)
    case feedbackViewMode = "feedbackViewMode"

    /// Dashboard view mode: kanban or list (environment-specific)
    case dashboardViewMode = "dashboardViewMode"

    /// Project list view mode: list, table, or grid (environment-specific)
    case projectViewMode = "projectViewMode"

    // MARK: - Global Settings
    /// Currently selected server environment (global)
    case selectedEnvironment = "selectedEnvironment"

    // MARK: - Debug Settings
    /// Simulated subscription tier for testing (debug-only)
    case simulatedSubscriptionTier = "simulatedSubscriptionTier"

    /// Flag to disable environment override (debug-only)
    case disableEnvironmentOverride = "disableEnvironmentOverride"

    /// Flag to simulate TestFlight build (debug-only)
    case simulateTestFlight = "simulateTestFlight"

    // MARK: - Properties

    /// Whether this key's data should be isolated per environment
    var isEnvironmentScoped: Bool {
        switch self {
        case .authToken,
             .keepMeSignedIn,
             .savedEmail,
             .savedPassword,
             .hasCompletedOnboarding,
             .feedbackViewMode,
             .dashboardViewMode,
             .projectViewMode:
            return true
        case .selectedEnvironment,
             .simulatedSubscriptionTier,
             .disableEnvironmentOverride,
             .simulateTestFlight:
            return false
        }
    }

    /// Fixed scope for non-environment-scoped keys
    var fixedScope: String? {
        switch self {
        case .selectedEnvironment:
            return "global"
        case .simulatedSubscriptionTier,
             .disableEnvironmentOverride,
             .simulateTestFlight:
            return "debug"
        default:
            return nil
        }
    }

    /// Whether this key is only available in DEBUG builds
    var isDebugOnly: Bool {
        switch self {
        case .simulatedSubscriptionTier,
             .disableEnvironmentOverride,
             .simulateTestFlight:
            return true
        default:
            return false
        }
    }
}
