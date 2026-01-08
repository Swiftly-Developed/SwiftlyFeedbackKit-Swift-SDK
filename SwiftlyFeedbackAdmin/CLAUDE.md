# CLAUDE.md - Feedback Kit Admin

Admin application for managing feedback projects and members.

## Build & Test

```bash
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -sdk iphonesimulator -configuration Debug
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
│   ├── Onboarding/   # Welcome, CreateAccount, VerifyEmail, ProjectChoice, CreateProject, JoinProject, Completion
│   ├── Projects/     # List, Detail, Create, Members, Slack/GitHub/ClickUp/Notion/Monday/Linear settings
│   ├── Feedback/     # Dashboard (List/Kanban), Detail, MergeSheet
│   ├── Users/        # Dashboard with stats and list
│   ├── Events/       # Dashboard with chart and time filter
│   └── Settings/     # Settings, DeveloperCommands
└── Services/         # AdminAPIClient, AuthService, KeychainService, Logger, SubscriptionService
```

## Key Flows

### Authentication
1. Login/Signup → 2. Email verification (8-char code) → 3. Token stored in Keychain

**Password Reset:** Forgot Password → Enter email → Enter code + new password → All sessions invalidated

### Onboarding (New Users)
1. Welcome → 2. Create Account → 3. Verify Email → 4. Project Choice → 5. Create/Join Project → 6. Completion

`OnboardingManager` singleton tracks completion in `UserDefaults`. Reset available in Developer Commands.

### RootView Navigation
- Not authenticated + not onboarded → `OnboardingContainerView`
- Not authenticated + onboarded → `AuthContainerView`
- Authenticated + needs verification → `EmailVerificationView`
- Authenticated + onboarded → `MainTabView`

## View Modes

**Project List:** List | Table | Grid (persisted via `@AppStorage`)

**Feedback Dashboard:** List | Kanban (drag-and-drop status changes)

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

## Developer Commands (DEBUG/TestFlight)

Available in Settings:
- Generate dummy projects/feedback/comments
- Reset onboarding
- Clear feedback / Delete all projects

## Subscription (Stub)

`SubscriptionService.shared` returns `.free` tier. RevenueCat not yet integrated.

## Platform Notes

**macOS:**
- `NavigationSplitView` with sidebar
- Sidebar sections: Top (Home, Projects, Feedback, Users, Events), Bottom (Feature Requests, Settings)

**iOS:**
- `TabView` with `.tabViewStyle(.sidebarAdaptable)` for iPad

## Feature Requests Tab

Dog-fooding: Admin app uses SwiftlyFeedbackKit for its own feature requests.

```swift
SwiftlyFeedback.configure(with: "sf_api_key")
SwiftlyFeedback.theme.primaryColor = .color(.blue)
```
