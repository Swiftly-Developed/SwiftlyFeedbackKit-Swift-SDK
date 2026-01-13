# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Note**: See [AGENTS.md](./AGENTS.md) for Swift and SwiftUI coding guidelines.

## Project Overview

Feedback Kit is a feedback collection platform with four subprojects:
- **SwiftlyFeedbackServer** - Vapor backend with PostgreSQL
- **SwiftlyFeedbackKit** - Swift SDK with SwiftUI views (iOS/macOS/visionOS)
- **SwiftlyFeedbackAdmin** - Admin app for managing feedback
- **SwiftlyFeedbackDemoApp** - Demo app showcasing the SDK

Each subproject has its own `CLAUDE.md` with detailed documentation.

## Git Remotes & Branching

This workspace pushes to multiple GitHub repositories:

| Remote | Repository | Purpose |
|--------|------------|---------|
| `origin` | [FeedbackKit-Workspace](https://github.com/Swiftly-Developed/FeedbackKit-Workspace.git) | Main workspace (all subprojects) |
| `feedbackkit-sdk` | [SwiftlyFeedbackKit](https://github.com/Swiftly-Developed/SwiftlyFeedbackKit.git) | SDK-only repo (for SPM distribution) |
| `feedbackkit-admin` | [SwiftlyFeedbackAdmin](https://github.com/Swiftly-Developed/SwiftlyFeedbackAdmin.git) | Admin app standalone repo |
| `feedbackkit-demo` | [SwiftlyFeedbackDemoApp](https://github.com/Swiftly-Developed/SwiftlyFeedbackDemoApp.git) | Demo app standalone repo |

**Branches:**
- `dev` - Development branch (default working branch)
- `testflight` - TestFlight/staging builds
- `main` - Production releases

**Pushing to remotes:**
```bash
# Push to main workspace (all changes)
git push origin dev

# Push SDK changes only (for SPM consumers)
git push feedbackkit-sdk dev

# Push Admin app changes
git push feedbackkit-admin dev

# Push Demo app changes
git push feedbackkit-demo dev

# Push all remotes at once
git push origin dev && git push feedbackkit-sdk dev && git push feedbackkit-admin dev && git push feedbackkit-demo dev
```

**Adding remotes (if missing):**
```bash
git remote add feedbackkit-sdk https://github.com/Swiftly-Developed/SwiftlyFeedbackKit.git
git remote add feedbackkit-admin https://github.com/Swiftly-Developed/SwiftlyFeedbackAdmin.git
git remote add feedbackkit-demo https://github.com/Swiftly-Developed/SwiftlyFeedbackDemoApp.git
```

## SDK Versioning (SwiftlyFeedbackKit)

SwiftlyFeedbackKit follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking API changes (removed/renamed public types, methods, properties)
- **MINOR** (0.X.0): New features, backward-compatible additions
- **PATCH** (0.0.X): Bug fixes, performance improvements, no API changes

### Release Checklist

1. **Update CHANGELOG.md** in `SwiftlyFeedbackKit/`
   - Add new version section with date
   - Document all changes under Added/Changed/Deprecated/Removed/Fixed/Security

2. **Create git tag**
   ```bash
   git tag X.Y.Z
   git push feedbackkit-sdk X.Y.Z
   git push origin X.Y.Z
   ```

3. **Create GitHub Release**
   - Go to https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases
   - Create release from tag with CHANGELOG content

### What Constitutes a Breaking Change

**MAJOR version required for:**
- Removing public types, methods, or properties
- Renaming public APIs
- Changing method signatures (parameters, return types)
- Changing behavior that existing code depends on
- Increasing minimum platform versions

**MINOR version for:**
- Adding new public types, methods, or properties
- Adding new parameters with default values
- New features that don't affect existing code

**PATCH version for:**
- Bug fixes
- Performance improvements
- Documentation updates
- Internal refactoring (no public API changes)

### SPM Version Constraints

Consumers can use:
```swift
// Recommended: accepts 1.x.x updates
.package(url: "...", from: "1.0.0")

// Alternative: accepts 1.0.x patches only
.package(url: "...", .upToNextMinor(from: "1.0.0"))

// Strict: exact version only
.package(url: "...", exact: "1.0.0")
```

## Tech Stack

- **Language**: Swift 6.2
- **Backend**: Vapor 4, Fluent ORM, PostgreSQL
- **Auth**: Token-based with bcrypt
- **Platforms**: iOS 26+, macOS 12+, visionOS 1+
- **Testing**: Swift Testing (`@Test`) + XCTest

## Build Commands

```bash
# Open workspace
open Swiftlyfeedback.xcworkspace

# Database (Docker)
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres

# Server
cd SwiftlyFeedbackServer && swift build
cd SwiftlyFeedbackServer && swift run          # http://localhost:8080
cd SwiftlyFeedbackServer && swift test

# SDK
cd SwiftlyFeedbackKit && swift build
cd SwiftlyFeedbackKit && swift test

# Admin app (IMPORTANT: test on both iOS and macOS)
xcodebuild -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -sdk iphonesimulator -configuration Debug
xcodebuild -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -destination 'platform=macOS' -configuration Debug
xcodebuild -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin test -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

# Demo app
xcodebuild -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackDemoApp -sdk iphonesimulator -configuration Debug
```

### Running Single Tests

```bash
# Server - single test file
cd SwiftlyFeedbackServer && swift test --filter TestClassName

# Server - single test method
cd SwiftlyFeedbackServer && swift test --filter TestClassName/testMethodName

# Xcode projects - single test
xcodebuild test -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -only-testing:SwiftlyFeedbackAdminTests/TestClassName/testMethodName -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SwiftlyFeedbackAdmin                         │
│                    (Admin app - iOS/macOS)                       │
│         Manages projects, members, feedback, analytics           │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Bearer Token Auth
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SwiftlyFeedbackServer                         │
│                      (Vapor 4 Backend)                           │
│  /api/v1 - Auth, Projects, Feedback, Votes, Comments, Events     │
└───────────────────────────┬─────────────────────────────────────┘
                            │ X-API-Key Auth
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SwiftlyFeedbackKit                            │
│                     (Swift SDK Package)                          │
│    FeedbackListView, SubmitFeedbackView, FeedbackDetailView      │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Embedded in
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SwiftlyFeedbackDemoApp                         │
│                  (Demo integration example)                      │
└─────────────────────────────────────────────────────────────────┘
```

**Auth Model:**
- Admin app uses Bearer token auth (user accounts)
- SDK uses X-API-Key auth (project API keys)

## Authorization Model

**Project Roles:**
- **Owner**: Full access (delete, archive, manage members, regenerate API key)
- **Admin**: Manage settings/members, update/delete feedback
- **Member**: View and respond to feedback
- **Viewer**: Read-only

**Key Rules:**
- Archived projects: reads allowed, writes blocked
- Voting blocked on `completed`/`rejected` status feedback
- `FeedbackStatus.canVote` indicates votability
- Feedback creators automatically get a vote (voteCount starts at 1)

## Feedback Statuses

| Status | Color | Can Vote |
|--------|-------|----------|
| pending | Gray | Yes |
| approved | Blue | Yes |
| in_progress | Orange | Yes |
| testflight | Cyan | Yes |
| completed | Green | No |
| rejected | Red | No |

Statuses are configurable per-project via Admin app or `PATCH /projects/:id/statuses`.

## SDK Configuration

```swift
// Basic setup
SwiftlyFeedback.configure(apiKey: "sf_...", baseURL: URL(string: "https://...")!)

// Disable submission (e.g., free users)
SwiftlyFeedback.config.allowFeedbackSubmission = false
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro!"

// Disable logging
SwiftlyFeedback.config.loggingEnabled = false

// Event tracking
SwiftlyFeedback.view("feature_details", properties: ["id": "123"])
SwiftlyFeedback.config.enableAutomaticViewTracking = false

// Voter notifications
SwiftlyFeedback.config.userEmail = "user@example.com"  // Pre-set email (skips dialog)
SwiftlyFeedback.config.showVoteEmailField = true       // Show email dialog when voting
SwiftlyFeedback.config.voteNotificationDefaultOptIn = false  // Default opt-in state
```

## Voter Email Notifications

Voters can optionally provide their email when voting to receive status change notifications.

**How it works:**
1. If `userEmail` is set, votes automatically use it (no dialog shown)
2. If `userEmail` is not set and `showVoteEmailField` is true, users see a dialog to optionally provide email
3. If opted-in, they receive emails when the feedback status changes
4. Each notification email contains a one-click unsubscribe link
5. Unsubscribe uses a unique permission key (UUID) - no authentication required
6. Email entered via dialog is saved to `userEmail` for future votes

**SDK Config:**
- `userEmail` (default: `nil`) - Pre-configured email. If set, votes use it automatically
- `showVoteEmailField` (default: `true`) - Show email dialog when voting (only if `userEmail` is nil)
- `voteNotificationDefaultOptIn` (default: `false`) - Default state of the "notify me" toggle
- `onUserEmailChanged` (default: `nil`) - Callback when email is set via vote dialog

**Server endpoints:**
- `POST /feedbacks/:id/votes` - Accepts optional `email` and `notifyStatusChange` fields
- `GET /votes/unsubscribe?key=UUID` - One-click unsubscribe (no auth required)

**Database fields added to Vote model:**
- `email` (String, nullable) - Voter's email address
- `notify_status_change` (Bool, default: false) - Opt-in flag
- `permission_key` (UUID, nullable) - Unique unsubscribe token

## Swift 6 Concurrency

Admin app uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Key patterns:

```swift
// DTOs must be nonisolated for Codable from any actor
nonisolated struct Feedback: Codable, Sendable { ... }

// Thread-safe services opt out
nonisolated enum KeychainService { ... }

// Global state flags
nonisolated(unsafe) private var _loggingEnabled = true
```

**Common fixes:**
- "Codable cannot be used in actor-isolated context" → Add `nonisolated` to type
- "Static method cannot be called from outside actor" → Mark type as `nonisolated`

## Integrations

All integrations support: create/bulk create, status sync, comment sync, link tracking, and active toggles.

| Integration | Push To | Status Sync | Extra Features |
|-------------|---------|-------------|----------------|
| Slack | Webhook | N/A | Notifications (new feedback, comments, status changes) |
| GitHub | Issues | Close/reopen | Labels |
| Notion | Database pages | Status property | Votes property |
| ClickUp | Tasks | Status | Tags, votes custom field |
| Linear | Issues | Workflow states | Labels, projects |
| Monday.com | Board items | Status column | Votes column |

**Status mapping** (all integrations follow similar pattern):
- pending → backlog/to do
- approved → approved/unstarted
- in_progress → in progress/started
- completed → complete/done
- rejected → closed/canceled

Configure via Admin app: Project Details > Menu (⋯) > [Integration] Integration.

See `SwiftlyFeedbackServer/CLAUDE.md` for API endpoints and request/response formats.

## Email Notifications

Via Resend API. User preferences in Settings:
- `notifyNewFeedback` / `notifyNewComments`

**Types:** New feedback, new comments, status changes, email verification, project invites, password reset.

**Branding:**
- Primary color: `#F7A50D` (FeedbackKit orange)
- Header gradient: `#FFB830` → `#F7A50D` → `#E85D04` (warm yellow-orange to deep orange-red)
- Logo: Hosted on Squarespace CDN, displayed in email header (60x60px)
- Footer: "Powered by Feedback Kit" branding

**Email templates** are defined in `SwiftlyFeedbackServer/Sources/App/Services/EmailService.swift` with reusable `emailHeader()` and `emailFooter()` helpers.

**Unsubscribe Link:** Notification emails (new feedback, new comments, status changes) include a "Manage email preferences" link in the footer. This uses the `feedbackkit://settings/notifications` URL scheme to deep link users to the app's Settings screen where they can toggle email preferences.

## Password Reset

1. User requests reset via email
2. Server sends 8-char code (1-hour expiry)
3. User enters code + new password
4. All sessions invalidated

## Keep Me Signed In (Admin App)

Allows users to stay signed in across app restarts by securely storing credentials in Keychain.

**How it works:**
1. User checks "Keep me signed in" toggle on login screen
2. On successful login, email and password are saved to Keychain (environment-scoped)
3. On app restart, if no valid token exists, app attempts auto re-login with saved credentials
4. If token expires mid-session, app automatically re-authenticates
5. On explicit logout, saved credentials are cleared

**Storage Keys (all environment-scoped):**
- `keepMeSignedIn` (Bool) - Whether the feature is enabled
- `savedEmail` (String) - User's email for auto re-login
- `savedPassword` (String) - User's password (stored securely in Keychain)

**Implementation:**
- `SecureStorageManager.saveCredentialsIfEnabled()` - Saves credentials after successful login
- `SecureStorageManager.getSavedCredentials()` - Returns credentials tuple if available
- `SecureStorageManager.clearSavedCredentials()` - Clears on logout or failed re-login
- `AuthViewModel.attemptAutoReLogin()` - Attempts login with saved credentials
- `AuthViewModel.isCheckingAuthState` - Prevents UI from loading until auth check completes

**Security:**
- Credentials stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Environment-scoped (dev credentials don't work in production)
- Cleared on explicit logout or when password changes (re-login fails)

## Feedback Merging

Select 2+ feedback items → Merge. Primary keeps title/description, votes are de-duplicated, comments migrated with prefix. Secondary items soft-deleted.

`POST /feedbacks/merge` with `primary_feedback_id` and `secondary_feedback_ids[]`.

## Onboarding Flow (Admin App)

**10 Steps:**
1. **Welcome 1** - App introduction with logo and feature highlights
2. **Welcome 2** - Collect Feedback (feature requests, bug reports)
3. **Welcome 3** - Integrations & Team collaboration
4. **Create Account** - Registration form (name, email, password)
5. **Verify Email** - 8-character code verification
6. **Paywall** - Subscription options with "Continue with Free" option
7. **Project Choice** - Create new / Join existing / Skip
8. **Create Project** OR **Join Project** - Project setup
9. **Completion** - Success screen with summary

`OnboardingManager` singleton tracks state in `UserDefaults`.

**Progress Bar:** Shown on all steps using the system accent color.

**Paywall Step:**
- Shows subscription options (Pro/Team) with feature comparison
- "Continue with Free" button allows skipping subscription
- In DEV/TestFlight environments, shows "All Features Unlocked" instead

**Environment Note (non-production):** The completion screen shows an `EnvironmentNoteSection` for DEV/TestFlight environments informing users about:
- All features being unlocked for testing
- 7-day data retention policy

## Developer Center (Admin App)

Available in DEBUG and TestFlight builds only. Access via:
- **macOS**: Menu bar → Feedback Kit → Developer Center... (⌘⇧D)
- **iOS**: Settings → Developer section

**Features:**
- Server environment switching (Localhost, Development, TestFlight, Production)
- Reset onboarding, auth token, UserDefaults
- Clear project feedback, delete all projects
- Storage management (view/clear stored keys)

**DEBUG-only features:**
- Generate dummy projects, feedback, and comments
- Subscription testing (tier override, reset purchases)
- Subscription simulation (client-side tier override)
- Full database reset

Controlled by `BuildEnvironment.canShowTestingFeatures` (DEBUG || TestFlight) and `BuildEnvironment.isDebug`.

## Server Environments (Admin App)

The Admin app supports multiple server environments configured via `AppEnvironment` enum:

| Environment | URL | Color | Available In |
|-------------|-----|-------|--------------|
| Localhost | `http://localhost:8080` | Purple | DEBUG only |
| Development | `api.feedbackkit.dev.swiftly-developed.com` | Blue | DEBUG only |
| TestFlight | `api.feedbackkit.testflight.swiftly-developed.com` | Orange | DEBUG, TestFlight builds |
| Production | `api.feedbackkit.prod.swiftly-developed.com` | Red | All builds |

**Build type restrictions:**
- **DEBUG**: All environments available, defaults to Development
- **TestFlight build**: TestFlight and Production only, defaults to TestFlight
- **App Store build**: Locked to Production

**Command line arguments** (DEBUG only):
- `--localhost` → Localhost
- `--dev-mode` → Development
- `--testflight-mode` → TestFlight
- `--prod-mode` → Production

**Environment switching behavior:**
- Switching environments logs out the user (tokens are environment-specific)
- Clears cached project data
- Updates API client base URL
- Shows confirmation dialog before switching
- `RootView` listens for `.environmentDidChange` notification

**Visual indicators:**
- Settings → About section shows current environment with color indicator
- `EnvironmentIndicator` component available for use throughout the app
- Non-production environments display colored capsule badges

**Configuration:** `SwiftlyFeedbackAdmin/Configuration/AppConfiguration.swift`

## Automatic Feedback Cleanup (Server)

Non-production environments (Localhost, Development, TestFlight) automatically delete feedback older than 7 days to keep test databases clean.

| Environment | Cleanup | Schedule |
|-------------|---------|----------|
| Localhost | Enabled | Every 24 hours (starting 30s after boot) |
| Development | Enabled | Every 24 hours (starting 30s after boot) |
| TestFlight (staging) | Enabled | Every 24 hours (starting 30s after boot) |
| Production | **Disabled** | N/A |

**What gets deleted:**
- Feedback items older than 7 days
- Associated comments and votes
- Merged feedback is preserved (items with `mergedIntoId` are skipped)

**Implementation:**
- `FeedbackCleanupScheduler` in `SwiftlyFeedbackServer/Sources/App/Jobs/FeedbackCleanupJob.swift`
- Uses Swift Concurrency (`Task`) for scheduling - no external dependencies
- Runs initial cleanup 30 seconds after server start, then every 24 hours
- Environment check uses `AppEnvironment.shared.isProduction`
- Called from `configure.swift` via `FeedbackCleanupScheduler.start(app:)`

**Warning in Admin App:**
- Developer Center shows a "7-Day Data Retention" warning banner for non-production environments
- Users are informed that their test data will be automatically cleaned up

## Subscription System (Admin App)

All builds (DEBUG, TestFlight, App Store) use RevenueCat for real subscription management. The paywall always shows purchase options.

**Usage in code:**
```swift
// Check if user has access (considers simulated tier in DEBUG)
if subscriptionService.meetsRequirement(.pro) { ... }

// Check actual subscription tier from RevenueCat
if subscriptionService.currentTier == .pro { ... }

// Get effective tier (simulated or actual)
let tier = subscriptionService.effectiveTier
```

## Tier Simulation (DEBUG Only)

DEBUG builds can simulate specific subscription tiers for testing tier-specific behavior:

```swift
#if DEBUG
// Set a simulated tier
subscriptionService.simulatedTier = .pro

// Clear simulation (returns to actual RevenueCat tier)
subscriptionService.clearSimulatedTier()
#endif
```

**Priority order for `effectiveTier`:**
1. Simulated tier (if set, DEBUG only)
2. Actual RevenueCat tier

**Access via Developer Center:**
- Settings → Developer Center → "Subscription Simulation" section
- Pick from None/Free/Pro/Team
- Shows "Currently simulating: [Tier]" indicator when active

**Note:** Tier simulation only affects the client. Server-side tier checks still use the actual subscription.

## Developer Server Tier Override (DEBUG Only)

In DEBUG builds for localhost/development environments, the paywall shows a "DEV: Unlock [Tier] on Server" button. This updates your server-side tier for testing without going through StoreKit.

## Reset Purchases (Developer Center)

The Developer Center has a "Reset Purchases" button that:
1. Clears RevenueCat local cache
2. Clears simulated tier
3. Re-authenticates with RevenueCat

This simulates a fresh/free user for testing the purchase flow.

**Server 402 Handling:**

When the server returns a 402 Payment Required response, the client shows the paywall.

**Pattern for handling 402 in sheets:**
1. User attempts action → API returns 402
2. Dismiss current sheet with flag set (`shouldShowPaywallAfterAddMember = true`)
3. On sheet dismiss, check flag and show PaywallView
4. After paywall dismisses, optionally re-open original sheet to retry

**Configuration:** `SwiftlyFeedbackAdmin/Services/SubscriptionService.swift`

## Build Environment Detection

`BuildEnvironment` detects the current distribution channel:

```swift
BuildEnvironment.isDebug        // Xcode DEBUG build
BuildEnvironment.isTestFlight   // TestFlight distribution
BuildEnvironment.isAppStore     // App Store distribution
BuildEnvironment.displayName    // "Debug", "TestFlight", or "App Store"
BuildEnvironment.canShowTestingFeatures  // true for DEBUG or TestFlight
```

**Compile-time detection:** Add `TESTFLIGHT` to Active Compilation Conditions for TestFlight builds.

**Runtime detection fallback:**
- iOS: Checks `appStoreReceiptURL` for `sandboxReceipt`
- macOS: Checks code signing certificate for TestFlight marker OID

**Configuration:** `SwiftlyFeedbackAdmin/Utilities/BuildEnvironment.swift`

## Analytics

- **Events**: `POST /events/track`, `GET /events/project/:id/stats?days=N`
- **Users**: Auto-registered on SDK init, tracks first/last seen, MRR
- **Dashboard**: Home tab shows KPIs, feedback by status, per-project stats
- **MRR**: Displayed on feedback cards, sortable

## Project Icons

`colorIndex` (0-7) maps to gradient pairs. Archived projects show gray.

## Deep Linking (URL Scheme)

The Admin app supports the `feedbackkit://` URL scheme for deep linking.

**Supported URLs:**
- `feedbackkit://settings` - Opens the Settings tab
- `feedbackkit://settings/notifications` - Opens the Settings tab (for managing email preferences)

**Implementation:**
- `DeepLinkManager` (singleton) handles URL parsing and navigation state
- `SwiftlyFeedbackAdminApp` uses `.onOpenURL` to capture incoming URLs
- `MainTabView` (iOS) and `MacNavigationView` (macOS) respond to `pendingDestination` changes

## Code Conventions

- `@main` for entry points
- `@Observable` + `Bindable()` for state
- `#Preview` macro for previews
- `@Test` macro for tests
- Models: `Codable`, `Sendable`, `Equatable`
- Platform: `#if os(macOS)` / `#if os(iOS)`

## Monetization

RevenueCat integration for subscription management.

| Tier | Projects | Feedback | Members | Integrations | Analytics |
|------|----------|----------|---------|--------------|-----------|
| Free | 1 | 10/project | No | No | Basic |
| Pro | 2 | Unlimited | No | Yes | Advanced + MRR |
| Team | Unlimited | Unlimited | Yes | Yes | Advanced + MRR |

**Feature Gating:**
- Use `subscriptionService.currentTier.meetsRequirement(.tier)` to check access
- Use `.tierBadge(.tier)` modifier to show tier badge on locked features
- Paywall accepts `requiredTier` parameter to show relevant packages only:
  ```swift
  PaywallView(requiredTier: .team)  // Shows only Team packages
  PaywallView(requiredTier: .pro)   // Shows only Pro packages (default)
  ```

**Feature → Tier Mapping:**
- Team Members: `.team` (both owner and invitee need Team tier)
- All Integrations (Slack, GitHub, Notion, etc.): `.pro`
- More than 1 project: `.pro`
- More than 2 projects: `.team`
- Unlimited feedback: `.pro`
- Advanced analytics: `.pro`
- Configurable statuses: `.pro`
- New comment notifications: `.pro`
- Voter email notifications: `.team`

## Server-Side Tier Enforcement

The server independently enforces subscription limits and returns 402 Payment Required errors. This is separate from client-side checks.

**Enforced Server-Side:**

| Feature | Tier | Enforcement |
|---------|------|-------------|
| Project limit | Pro/Team | `POST /projects` - max 1 (Free), 2 (Pro), unlimited (Team) |
| Feedback limit | Pro | `POST /feedbacks` - max 10 per project (Free) |
| Team member invite | Team | `POST /projects/:id/members` - owner must have Team |
| Team member accept | Team | `POST /projects/invites/:code/accept` - both parties need Team |
| Configurable statuses | Pro | `PATCH /projects/:id/statuses` |
| Integrations | Pro | All integration endpoints (Slack, GitHub, etc.) |
| Comment notifications | Pro | Server only sends to Pro+ users, silently enforces on settings update |
| Voter notifications | Team | Server only sends if project owner has Team tier |

**Silent Enforcement (no 402):**
- Comment notifications: Free users with `notifyNewComments=true` in DB don't receive emails
- Voter notifications: Silently disabled if project owner isn't Team tier

**Team Member Rules:**
- Project owner must have Team tier to send invites
- Invitee must have Team tier to accept
- If owner downgrades after sending invite, accept fails with 402
