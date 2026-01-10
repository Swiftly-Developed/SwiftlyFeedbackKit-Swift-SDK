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

# Admin app
xcodebuild -workspace Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -sdk iphonesimulator -configuration Debug
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
```

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

## Feedback Merging

Select 2+ feedback items → Merge. Primary keeps title/description, votes are de-duplicated, comments migrated with prefix. Secondary items soft-deleted.

`POST /feedbacks/merge` with `primary_feedback_id` and `secondary_feedback_ids[]`.

## Onboarding Flow (Admin App)

1. Welcome → 2. Create Account → 3. Verify Email → 4. Project Choice → 5. Create/Join Project → 6. Completion

`OnboardingManager` singleton tracks state in `UserDefaults`.

## Developer Commands (Admin App)

Available in DEBUG and TestFlight builds only. Access via:
- **macOS**: Menu bar → Feedback Kit → Developer Commands... (⌘⇧D)
- **iOS**: Settings → Developer section

**Features:**
- Server environment switching (Localhost, Development, TestFlight, Production)
- Generate dummy projects, feedback, and comments
- Reset onboarding, auth token, UserDefaults
- Clear project feedback, delete all projects
- Full database reset (DEBUG only - not available in TestFlight)

Controlled by `BuildEnvironment.canShowTestingFeatures` (DEBUG || TestFlight) and `BuildEnvironment.isDebug`.

## Server Environments (Admin App)

The Admin app supports multiple server environments configured via `AppEnvironment` enum:

| Environment | URL | Color | Available In |
|-------------|-----|-------|--------------|
| Localhost | `http://localhost:8080` | Purple | DEBUG only |
| Development | `feedbackkit-dev-*.herokuapp.com` | Blue | DEBUG only |
| TestFlight | `feedbackkit-testflight-*.herokuapp.com` | Orange | DEBUG, TestFlight builds |
| Production | `feedbackkit-production-*.herokuapp.com` | Red | All builds |

**Build type restrictions:**
- **DEBUG**: All environments available, defaults to Development
- **TestFlight build**: TestFlight and Production only, defaults to TestFlight
- **App Store build**: Locked to Production

**Command line arguments** (DEBUG only):
- `--localhost` → Localhost
- `--dev-mode` → Development
- `--testflight-mode` → TestFlight
- `--prod-mode` → Production

**Configuration:** `SwiftlyFeedbackAdmin/Configuration/AppConfiguration.swift`

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
| Pro | 2 | Unlimited | No | No | Advanced + MRR |
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
- Team Members: `.team`
- All Integrations (Slack, GitHub, Notion, etc.): `.team`
- More than 1 project: `.pro`
- More than 2 projects: `.team`
- Unlimited feedback: `.pro`
- Advanced analytics: `.pro`
- Configurable statuses: `.pro`
