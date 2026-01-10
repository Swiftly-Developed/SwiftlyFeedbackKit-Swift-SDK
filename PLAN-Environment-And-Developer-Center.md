# Environment & Developer Center Implementation Plan

## Overview

This plan implements a multi-phase approach to:
1. Make server environment publicly configurable
2. Rename "Developer Commands" to "Developer Center"
3. Allow free access to all features in DEV/TestFlight environments
4. Auto-delete feedback after 7 days in DEV/TestFlight
5. Add environment selector and FeedbackKit logo to login screen

---

## Phase 1: Public Environment Configuration

### Goal
Make the server environment publicly accessible and editable from login screen.

### Files to Modify

#### 1. `SwiftlyFeedbackAdmin/Configuration/AppConfiguration.swift`

**Changes:**
- Make `currentEnvironment` publicly settable
- Store selected environment in UserDefaults (persist across launches)
- Add method to change environment at runtime

```swift
// Current (approximate)
enum AppEnvironment {
    case localhost, development, testflight, production

    static var current: AppEnvironment { ... }  // Read-only, computed
}

// New
enum AppEnvironment: String, CaseIterable, Codable {
    case localhost, development, testflight, production

    /// The currently selected environment (persisted)
    static var current: AppEnvironment {
        get {
            // Check build restrictions first
            #if !DEBUG
            if BuildEnvironment.isAppStore {
                return .production  // Locked for App Store
            }
            #endif

            // Load from UserDefaults
            if let saved = UserDefaults.standard.string(forKey: "selectedEnvironment"),
               let env = AppEnvironment(rawValue: saved) {
                // Validate environment is available for this build
                if env.isAvailable { return env }
            }
            return defaultEnvironment
        }
        set {
            guard newValue.isAvailable else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedEnvironment")
            // Post notification for any listeners
            NotificationCenter.default.post(name: .environmentDidChange, object: newValue)
        }
    }

    /// Whether this environment is available for the current build type
    var isAvailable: Bool {
        switch self {
        case .localhost, .development:
            return BuildEnvironment.isDebug
        case .testflight:
            return BuildEnvironment.isDebug || BuildEnvironment.isTestFlight
        case .production:
            return true
        }
    }

    /// Environments available for selection in current build
    static var availableEnvironments: [AppEnvironment] {
        allCases.filter { $0.isAvailable }
    }
}

extension Notification.Name {
    static let environmentDidChange = Notification.Name("environmentDidChange")
}
```

#### 2. `SwiftlyFeedbackAdmin/Views/Auth/LoginView.swift`

**Changes:**
- Add environment picker (only shown when multiple environments available)
- Replace app icon with FeedbackKit logo

```swift
// Add to LoginView
@State private var selectedEnvironment = AppEnvironment.current

var body: some View {
    VStack {
        // FeedbackKit Logo (replace current icon)
        Image("FeedbackKitLogo")  // or use SF Symbol / gradient icon
            .resizable()
            .frame(width: 80, height: 80)

        Text("Feedback Kit")
            .font(.largeTitle.bold())

        // Environment picker (if multiple available)
        if AppEnvironment.availableEnvironments.count > 1 {
            environmentPicker
        }

        // ... existing login form
    }
}

@ViewBuilder
private var environmentPicker: some View {
    Menu {
        ForEach(AppEnvironment.availableEnvironments, id: \.self) { env in
            Button {
                selectedEnvironment = env
                AppEnvironment.current = env
            } label: {
                HStack {
                    Text(env.displayName)
                    if env == selectedEnvironment {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    } label: {
        HStack {
            Circle()
                .fill(selectedEnvironment.color)
                .frame(width: 8, height: 8)
            Text(selectedEnvironment.displayName)
                .font(.caption)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
```

#### 3. Add FeedbackKit Logo Asset

**Location:** `SwiftlyFeedbackAdmin/Assets.xcassets/FeedbackKitLogo.imageset/`

**Options:**
- Use existing logo from email templates
- Create SF Symbol-style gradient icon programmatically

### Testing Checklist - Phase 1
- [ ] Environment persists across app launches
- [ ] DEBUG build shows all 4 environments
- [ ] TestFlight build shows TestFlight + Production only
- [ ] App Store build locked to Production (no picker shown)
- [ ] Environment change triggers app reconfiguration
- [ ] FeedbackKit logo displays on login screen
- [ ] Environment picker styled correctly

---

## Phase 2: Rename Developer Commands → Developer Center

### Goal
Rename all references from "Developer Commands" to "Developer Center".

### Files to Modify

#### 1. `SwiftlyFeedbackAdmin/Views/Settings/DeveloperCommandsView.swift`

**Rename file to:** `DeveloperCenterView.swift`

**Changes:**
```swift
// Rename struct
struct DeveloperCenterView: View {
    var body: some View {
        List {
            // ... existing content
        }
        .navigationTitle("Developer Center")
    }
}
```

#### 2. `SwiftlyFeedbackAdmin/Views/Settings/SettingsView.swift`

**Changes:**
```swift
// Update navigation link
NavigationLink {
    DeveloperCenterView()
} label: {
    Label("Developer Center", systemImage: "hammer.fill")
}
```

#### 3. `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdminApp.swift` (macOS menu)

**Changes:**
```swift
// Update menu item
CommandGroup(after: .appSettings) {
    Button("Developer Center...") {
        showDeveloperCenter = true
    }
    .keyboardShortcut("D", modifiers: [.command, .shift])
}
```

#### 4. Update CLAUDE.md references

**Changes:**
- Replace "Developer Commands" with "Developer Center" throughout

### Testing Checklist - Phase 2
- [ ] iOS: Settings shows "Developer Center"
- [ ] macOS: Menu shows "Developer Center..." (⌘⇧D)
- [ ] Navigation title is "Developer Center"
- [ ] All functionality preserved

---

## Phase 3: Free Features in DEV/TestFlight

### Goal
Bypass paywall and enable all features when using DEV or TestFlight environments.

### Files to Modify

#### 1. `SwiftlyFeedbackAdmin/Services/SubscriptionService.swift`

**Changes:**
```swift
class SubscriptionService: ObservableObject {
    @Published var currentTier: SubscriptionTier = .free

    /// Whether the current environment grants free access to all features
    var hasEnvironmentOverride: Bool {
        let env = AppEnvironment.current
        return env == .localhost || env == .development || env == .testflight
    }

    /// Effective tier considering environment override
    var effectiveTier: SubscriptionTier {
        if hasEnvironmentOverride {
            return .team  // Full access
        }
        return currentTier
    }

    /// Check if user meets tier requirement (considering environment)
    func meetsRequirement(_ required: SubscriptionTier) -> Bool {
        effectiveTier.meetsRequirement(required)
    }
}
```

#### 2. `SwiftlyFeedbackAdmin/Views/Settings/FeatureGatedView.swift`

**Changes:**
```swift
struct FeatureGatedView<Content: View>: View {
    let requiredTier: SubscriptionTier
    let content: Content
    @EnvironmentObject var subscriptionService: SubscriptionService

    var body: some View {
        if subscriptionService.meetsRequirement(requiredTier) {
            content
            // Show indicator if access is via environment override
            if subscriptionService.hasEnvironmentOverride &&
               !subscriptionService.currentTier.meetsRequirement(requiredTier) {
                environmentOverrideBadge
            }
        } else {
            // Show paywall
            PaywallView(requiredTier: requiredTier)
        }
    }

    private var environmentOverrideBadge: some View {
        Text("DEV MODE")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange)
            .clipShape(Capsule())
    }
}
```

#### 3. `SwiftlyFeedbackAdmin/Views/Settings/PaywallView.swift`

**Changes:**
```swift
struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService

    var body: some View {
        // If environment override active, don't show paywall
        if subscriptionService.hasEnvironmentOverride {
            // This shouldn't be reached, but safety fallback
            Text("All features unlocked in \(AppEnvironment.current.displayName)")
        } else {
            // ... existing paywall content
        }
    }
}
```

#### 4. Add Developer Center toggle (optional manual override)

**In `DeveloperCenterView.swift`:**
```swift
Section("Feature Access") {
    Toggle("Override Subscription (All Features)", isOn: $forceAllFeatures)
        .disabled(AppEnvironment.current == .production)

    if AppEnvironment.current != .production {
        Text("DEV/TestFlight environments automatically unlock all features")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

### Testing Checklist - Phase 3
- [ ] Localhost: All features unlocked
- [ ] Development: All features unlocked
- [ ] TestFlight: All features unlocked
- [ ] Production: Normal paywall behavior
- [ ] "DEV MODE" badge shown on unlocked features
- [ ] Switching environment updates feature access immediately

---

## Phase 4: Auto-Delete Feedback After 7 Days (Server)

### Goal
Automatically delete feedback older than 7 days on DEV and TestFlight servers.

### Files to Modify

#### 1. `SwiftlyFeedbackServer/Sources/App/Jobs/CleanupJob.swift` (NEW FILE)

**Create scheduled job:**
```swift
import Vapor
import Fluent
import Queues

struct FeedbackCleanupJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let app = context.application

        // Only run on non-production environments
        guard let environment = Environment.get("APP_ENVIRONMENT"),
              environment != "production" else {
            app.logger.info("Skipping cleanup - production environment")
            return
        }

        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)  // 7 days ago

        // Delete old feedback and related data
        let oldFeedback = try await Feedback.query(on: app.db)
            .filter(\.$createdAt < cutoffDate)
            .all()

        for feedback in oldFeedback {
            // Delete comments
            try await Comment.query(on: app.db)
                .filter(\.$feedback.$id == feedback.id!)
                .delete()

            // Delete votes
            try await Vote.query(on: app.db)
                .filter(\.$feedback.$id == feedback.id!)
                .delete()

            // Delete feedback
            try await feedback.delete(on: app.db)
        }

        app.logger.info("Cleaned up \(oldFeedback.count) feedback items older than 7 days")
    }
}
```

#### 2. `SwiftlyFeedbackServer/Sources/App/configure.swift`

**Register the job:**
```swift
func configure(_ app: Application) async throws {
    // ... existing config

    // Schedule cleanup job (runs daily at 3 AM)
    app.queues.schedule(FeedbackCleanupJob())
        .daily()
        .at(.init(stringLiteral: "03:00"))

    try app.queues.startScheduledJobs()
}
```

#### 3. Add environment variable to Heroku

**For DEV and TestFlight servers:**
```bash
heroku config:set APP_ENVIRONMENT=development --app feedbackkit-dev-xxx
heroku config:set APP_ENVIRONMENT=testflight --app feedbackkit-testflight-xxx
heroku config:set APP_ENVIRONMENT=production --app feedbackkit-production-xxx
```

#### 4. Show warning in Admin app

**In `DeveloperCenterView.swift` or Dashboard:**
```swift
if AppEnvironment.current != .production {
    WarningBanner(
        icon: "clock.badge.exclamationmark",
        message: "Feedback on \(AppEnvironment.current.displayName) is automatically deleted after 7 days"
    )
}
```

### Testing Checklist - Phase 4
- [ ] Cleanup job runs on DEV server
- [ ] Cleanup job runs on TestFlight server
- [ ] Cleanup job skipped on Production server
- [ ] Feedback older than 7 days deleted
- [ ] Related comments and votes also deleted
- [ ] Warning banner shown in Admin app for non-production

---

## Phase 5: Polish & Integration

### Goal
Final integration, edge cases, and UI polish.

### Tasks

#### 1. Environment change handling

**When environment changes:**
- Log out user (tokens are environment-specific)
- Clear cached data
- Reset API client with new base URL

```swift
// In AppConfiguration or AuthManager
func handleEnvironmentChange(to newEnvironment: AppEnvironment) {
    // Clear auth token
    AuthManager.shared.logout()

    // Clear caches
    ProjectCache.shared.clear()

    // Update API client
    APIClient.shared.updateBaseURL(newEnvironment.baseURL)

    // Show confirmation
    ToastManager.shared.show("Switched to \(newEnvironment.displayName)")
}
```

#### 2. Visual indicators

**Show current environment throughout app:**
- Status bar indicator (non-production)
- Settings header showing environment
- Color-coded navigation bar (subtle)

```swift
// Environment indicator view
struct EnvironmentIndicator: View {
    let environment = AppEnvironment.current

    var body: some View {
        if environment != .production {
            HStack(spacing: 4) {
                Circle()
                    .fill(environment.color)
                    .frame(width: 6, height: 6)
                Text(environment.displayName.uppercased())
                    .font(.caption2.bold())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(environment.color.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}
```

#### 3. Onboarding updates

**If user is on DEV/TestFlight:**
- Show note that all features are unlocked for testing
- Mention 7-day data retention

### Testing Checklist - Phase 5
- [ ] Environment change logs out user
- [ ] Environment indicator visible in non-production
- [ ] API calls go to correct server after environment change
- [ ] No data leakage between environments
- [ ] Smooth UX when switching environments

---

## Summary

| Phase | Description | Effort |
|-------|-------------|--------|
| **Phase 1** | Public environment config + login UI | Medium |
| **Phase 2** | Rename to Developer Center | Small |
| **Phase 3** | Free features in DEV/TestFlight | Medium |
| **Phase 4** | Auto-delete feedback (server) | Medium |
| **Phase 5** | Polish & integration | Small |

## Dependencies

```
Phase 1 ──┬── Phase 2 (can run parallel)
          │
          └── Phase 3 (depends on Phase 1)
                │
                └── Phase 4 (depends on Phase 3 for warnings)
                      │
                      └── Phase 5 (final polish)
```

## Risk Considerations

1. **Data loss**: Users might accidentally use DEV/TestFlight and lose data after 7 days
   - **Mitigation**: Clear warning banners, confirmation dialogs

2. **Token mismatch**: Switching environments with cached tokens could cause auth errors
   - **Mitigation**: Force logout on environment change

3. **Feature confusion**: Users might think they have paid features when using DEV
   - **Mitigation**: "DEV MODE" badges, clear messaging
