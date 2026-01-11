# CLAUDE.md - Feedback Kit Admin

Admin application for managing feedback projects and members.

## Build & Test

**IMPORTANT:** Always test builds on both iOS and macOS to catch platform-specific issues.

```bash
# iOS build
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -sdk iphonesimulator -configuration Debug

# macOS build
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -destination 'platform=macOS' -configuration Debug

# iOS tests
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin test -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Directory Structure

```
SwiftlyFeedbackAdmin/
├── SwiftlyFeedbackAdminApp.swift
├── Models/           # Auth, Project, Feedback, SDKUser, ViewEvent, HomeDashboard models
├── ViewModels/       # Auth, Project, Feedback, SDKUser, ViewEvent, HomeDashboard, Onboarding VMs
├── Views/
│   ├── RootView.swift, MainTabView.swift
│   ├── Home/         # HomeDashboardView
│   ├── Auth/         # Login, Signup, EmailVerification, ForgotPassword
│   ├── Components/   # Shared UI components (PasswordStrengthView)
│   ├── Onboarding/   # Welcome, CreateAccount, VerifyEmail, ProjectChoice, CreateProject, JoinProject, Completion
│   ├── Projects/     # List, Detail, Create, Members, Slack/GitHub/ClickUp/Notion/Monday/Linear settings
│   ├── Feedback/     # Dashboard (List/Kanban), Detail, MergeSheet
│   ├── Users/        # Dashboard with stats and list
│   ├── Events/       # Dashboard with chart and time filter
│   └── Settings/     # Settings, DeveloperCommands
├── Services/         # AdminAPIClient, AuthService, Logger, SubscriptionService
│   └── Storage/      # Secure storage layer (see Storage Architecture below)
```

## Key Flows

### Authentication
1. Login/Signup → 2. Email verification (8-char code) → 3. Token stored via `SecureStorageManager`

**Keep Me Signed In:** Toggle on login screen saves credentials to Keychain for automatic re-login on app restart or session expiry.

**Password Reset:** Forgot Password → Enter email → Enter code + new password → All sessions invalidated

**Password Validation UI:** All password fields (Signup, Onboarding, Password Reset) use `PasswordStrengthView` component:
- 4-bar visual strength indicator (Weak/Medium/Strong/Very Strong)
- Color-coded feedback (red → orange → green)
- Optional "Passwords match" indicator
- Scoring: length (8+, 12+), uppercase, numbers, special characters

### Onboarding (New Users)
1. Welcome → 2. Create Account → 3. Verify Email → 4. Project Choice → 5. Create/Join Project → 6. Completion

`OnboardingManager` singleton tracks completion in Keychain (via `SecureStorageManager`). Reset available in Developer Commands.

### RootView Navigation
- Not authenticated + not onboarded → `OnboardingContainerView`
- Not authenticated + onboarded → `AuthContainerView`
- Authenticated + needs verification → `EmailVerificationView`
- Authenticated + onboarded → `MainTabView`

## View Modes

**Project List:** List | Table | Grid (persisted via `@SecureAppStorage`)

**Feedback Dashboard:** List | Kanban (drag-and-drop status changes, persisted via `@SecureAppStorage`)

**Feedback List:** List | Kanban (persisted via `@SecureAppStorage`)

View mode preferences are environment-scoped (via `SecureStorageManager`), so different server environments can have different view preferences.

## Shared Project Filter

Feedback, Users, and Events tabs share `ProjectViewModel.selectedFilterProject`. Uses `.task(id:)` for reactive loading.

## Integrations

Each integration settings view: Slack, GitHub, ClickUp, Notion, Monday.com, Linear.

**Common features:**
- Active toggle to pause without removing config
- Context menu: "Push to [Integration]" / "View [Integration] Item"
- Bulk actions in selection action bar
- Badge on feedback cards when linked

**Integration icons** (compact mode for Kanban): 18x18 circular icons via `IntegrationIconBadge`.

## Feedback Merging

1. Select 2+ items → 2. "Merge Selected" → 3. Choose primary → 4. Confirm

Merge badge shows count on cards. Votes de-duplicated, comments prefixed with origin.

## Events Dashboard

- Stats: Total events, unique users
- Daily events chart (Swift Charts)
- Time period filter: 7d, 30d (default), 90d, 1y, or custom
- Event breakdown by type

## Logging

```swift
AppLogger.isEnabled = false  // Disable all logging

// Categories: api, auth, viewModel, view, data, keychain, subscription
AppLogger.api.info("Loading...")
```

Uses `nonisolated` + `@unchecked Sendable` for Swift 6 compatibility.

## Storage Architecture

**IMPORTANT: Only use Keychain storage. Do NOT use UserDefaults or @AppStorage.**

All persistent data uses Keychain storage via the `Storage/` module:

```
Storage/
├── SecureStorageManager.swift  # Unified storage interface
├── KeychainManager.swift       # Low-level Keychain operations
├── StorageKey.swift            # Type-safe storage key enum
└── SecureAppStorage.swift      # SwiftUI property wrapper (@AppStorage replacement)
```

**Why Keychain only:**
- Consistent secure storage across all data types
- Environment-scoped keys (different data per server environment)
- No migration complexity between storage systems
- Data persists across app reinstalls (Keychain behavior)

### SecureStorageManager

Environment-aware storage with automatic key scoping:

```swift
// Get/set values (automatically scoped to current environment)
let token: String? = SecureStorageManager.shared.get(.authToken)
SecureStorageManager.shared.set("token", for: .authToken)

// Convenience properties
SecureStorageManager.shared.authToken = "..."
SecureStorageManager.shared.hasCompletedOnboarding = true

// Bulk operations
SecureStorageManager.shared.clearEnvironment(.development)
SecureStorageManager.shared.clearDebugSettings()
```

### StorageKey

Type-safe enum with scope configuration:

| Key | Scope | Description |
|-----|-------|-------------|
| `.authToken` | Environment | Bearer token for API |
| `.keepMeSignedIn` | Environment | Keep me signed in toggle |
| `.savedEmail` | Environment | Email for auto re-login |
| `.savedPassword` | Environment | Password for auto re-login |
| `.hasCompletedOnboarding` | Environment | Onboarding completion |
| `.feedbackViewMode` | Environment | List/Kanban preference |
| `.dashboardViewMode` | Environment | Dashboard view preference |
| `.projectViewMode` | Environment | Project list preference |
| `.selectedEnvironment` | Global | Current server environment |
| `.simulatedSubscriptionTier` | Debug | Tier simulation (DEBUG only) |
| `.disableEnvironmentOverride` | Debug | Disable tier override |
| `.simulateTestFlight` | Debug | Simulate TestFlight build |

### SecureAppStorage

SwiftUI property wrapper for secure storage:

```swift
@SecureAppStorage(.feedbackViewMode) private var viewMode: String = "list"
```

Provides `@AppStorage`-like functionality with Keychain backing and environment scoping. Use this instead of `@AppStorage` for all persistent UI preferences.

## Developer Commands (DEBUG/TestFlight)

Available in Settings (iOS) or Menu bar (macOS ⌘⇧D):
- Server environment switching
- Generate dummy projects/feedback/comments
- Reset onboarding, auth token, storage
- Clear feedback / Delete all projects
- Full database reset (DEBUG only)

## Server Environments

`AppEnvironment` enum in `Configuration/AppConfiguration.swift`:

| Environment | Color | Available In |
|-------------|-------|--------------|
| `.localhost` | Purple | DEBUG only |
| `.development` | Blue | DEBUG only |
| `.testflight` | Orange | DEBUG, TestFlight builds |
| `.production` | Red | All builds |

```swift
// Access current environment
AppConfiguration.shared.environment
AppConfiguration.shared.baseURL
AppConfiguration.shared.apiV1URL

// Switch environment (auto-reconfigures SDK)
AppConfiguration.shared.switchTo(.development)

// Check environment
AppConfiguration.isLocalhost
AppConfiguration.isDevelopmentMode
AppConfiguration.isTestFlightMode
AppConfiguration.isProductionMode
```

**SDK API Keys** per environment are configured in `AppEnvironment.sdkAPIKey`.

## Subscription (RevenueCat)

`SubscriptionService.shared` manages subscriptions via RevenueCat.

**Tiers:** Free, Pro, Team (see root CLAUDE.md for feature breakdown)

**Key properties:**
- `currentTier` - Actual tier from RevenueCat
- `effectiveTier` - Tier considering environment override/simulation
- `meetsRequirement(_:)` - Check access (uses `effectiveTier`)
- `hasEnvironmentOverride` - True in DEBUG for non-production environments

**Environment Override (DEBUG only):**
- Non-production environments automatically unlock Team tier
- Disable via `disableEnvironmentOverrideForTesting` for testing tier gating

**Tier Simulation (DEBUG only):**
- `simulatedTier` - Override tier for testing specific behaviors
- Available in Developer Center → Subscription Simulation

## Platform Notes

**macOS:**
- `NavigationSplitView` with sidebar
- Sidebar sections: Top (Home, Projects, Feedback, Users, Events), Bottom (Feature Requests, Settings)

**iOS:**
- `TabView` with `.tabViewStyle(.sidebarAdaptable)` for iPad

## Feature Requests Tab

Dog-fooding: Admin app uses SwiftlyFeedbackKit for its own feature requests.

SDK is configured automatically at app launch via `AppConfiguration.shared.configureSDK()`:
- Uses environment-specific API key from `AppEnvironment.sdkAPIKey`
- Reconfigures automatically when switching environments
- Theme: Blue primary color

## Build Environment Detection

`BuildEnvironment` in `Utilities/BuildEnvironment.swift` detects distribution channel:

```swift
BuildEnvironment.isDebug              // Xcode DEBUG build
BuildEnvironment.isTestFlight         // TestFlight distribution
BuildEnvironment.isAppStore           // App Store distribution
BuildEnvironment.canShowTestingFeatures  // DEBUG || TestFlight
BuildEnvironment.displayName          // "Debug", "TestFlight", or "App Store"

// Simulate TestFlight in DEBUG
BuildEnvironment.simulateTestFlight = true
```

**Compile-time:** Add `TESTFLIGHT` to Active Compilation Conditions for reliable detection.
