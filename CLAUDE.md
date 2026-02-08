# CLAUDE.md - Feedback Kit SDK

Swift SDK with SwiftUI views for integrating feedback into iOS/macOS/visionOS apps.

## Build & Test

```bash
swift build
swift test
swift test --filter TestClassName/testMethodName  # Single test
```

## Platforms

- iOS 26+
- macOS 26+
- visionOS 26+

## Directory Structure

```
Sources/SwiftlyFeedbackKit/
├── SwiftlyFeedback.swift        # Main entry point & configuration
├── Configuration/
│   ├── Config.swift             # SDK options
│   └── EnvironmentAPIKeys.swift # Multi-environment keys
├── Utilities/
│   └── BuildEnvironment.swift   # Build type detection
├── Models/
│   ├── Feedback.swift           # Feedback model
│   ├── Comment.swift            # Comment model
│   ├── VoteResult.swift         # Vote result
│   └── ViewEvent.swift          # Event tracking
├── Networking/
│   ├── APIClient.swift          # HTTP client
│   └── SwiftlyFeedbackError.swift
└── Views/
    ├── FeedbackListView.swift
    ├── FeedbackRowView.swift
    ├── FeedbackDetailView.swift
    └── SubmitFeedbackView.swift
```

## SDK Configuration

### Recommended Setup (Explicit Environment)

```swift
import SwiftlyFeedbackKit

// In your App's init()
#if DEBUG
SwiftlyFeedback.configure(environment: .development, key: "your-dev-key")
#elseif TESTFLIGHT
SwiftlyFeedback.configure(environment: .testflight, key: "your-staging-key")
#else
SwiftlyFeedback.configure(environment: .production, key: "your-prod-key")
#endif
```

| Environment | Server |
|-------------|--------|
| `.development` | localhost:8080 |
| `.testflight` | staging server |
| `.production` | production server |

> **Note:** Add `TESTFLIGHT` to your target's **Active Compilation Conditions** in Build Settings for TestFlight builds.

### Alternative: Auto-Detection

```swift
// May be unreliable in some cases (uses AppTransaction with timeout)
SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
    debug: "sf_local_...",        // Optional: localhost
    testflight: "sf_staging_...",  // Required: staging server
    production: "sf_prod_..."      // Required: production server
))
```

> **Security:** Store API keys in Info.plist with xcconfig files, not hardcoded.

### Configuration Options

```swift
// Disable submission (e.g., for free users)
SwiftlyFeedback.config.allowFeedbackSubmission = false
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro!"

// Disable logging
SwiftlyFeedback.config.loggingEnabled = false

// Event tracking
SwiftlyFeedback.view("feature_details", properties: ["id": "123"])
SwiftlyFeedback.config.enableAutomaticViewTracking = false
```

### Vote Notification Options

```swift
// Pre-set email (skips dialog when voting)
SwiftlyFeedback.config.userEmail = "user@example.com"

// Show email dialog when voting (only if userEmail is nil)
SwiftlyFeedback.config.showVoteEmailField = true

// Default state of "notify me" toggle
SwiftlyFeedback.config.voteNotificationDefaultOptIn = false

// Callback when email is set via vote dialog
SwiftlyFeedback.config.onUserEmailChanged = { email in
    UserDefaults.standard.set(email ?? "", forKey: "userEmail")
}
```

## Using the SDK

### SwiftUI Views

```swift
// Pre-built views
FeedbackListView()
SubmitFeedbackView()
FeedbackDetailView(feedback: someFeedback)
```

### Direct API Access

```swift
let feedback = try await SwiftlyFeedback.shared?.getFeedback()
try await SwiftlyFeedback.shared?.submitFeedback(title: "...", description: "...")
try await SwiftlyFeedback.shared?.vote(for: feedbackId)
```

### Event Tracking

```swift
// Custom events
SwiftlyFeedback.view("onboarding_step_1")
SwiftlyFeedback.view("purchase_completed", properties: ["amount": "9.99"])

// Predefined views
SwiftlyFeedback.view(.feedbackList)
SwiftlyFeedback.view(.feedbackDetail)
SwiftlyFeedback.view(.submitFeedback)
```

## Models

All models are `Codable`, `Sendable`, `Equatable`, and `Identifiable`.

**FeedbackStatus:**
- Cases: `pending`, `approved`, `inProgress`, `testflight`, `completed`, `rejected`
- `canVote` - Returns `false` for `completed`/`rejected`
- `displayName` - User-friendly name

**Feedback:**
- `mergedIntoId` - Points to primary if merged
- `isMerged` - Computed property
- `mergedFeedbackIds` - Array of merged IDs (for primary)

## FeedbackListView Features

### Sorting

| Option | Description |
|--------|-------------|
| `.votes` | Highest vote count first (default) |
| `.newest` | Most recently created first |
| `.oldest` | Oldest first |

Sort picker in toolbar menu. Sorting applied client-side with smooth animation.

### Request Deduplication

- `loadTask` tracks in-flight requests
- New requests cancel pending ones
- `loadFeedbackIfNeeded()` prevents duplicate initial loads
- Cancelled requests silently ignored (no error alerts)

## Error Handling

**SwiftlyFeedbackError cases:**
- `invalidResponse`, `badRequest(message:)`, `unauthorized`
- `invalidApiKey` - Distinct from generic unauthorized
- `notFound`, `conflict`, `serverError(statusCode:)`
- `networkError(underlying:)`, `decodingError(underlying:)`

**Invalid API Key Handling:**
- Views detect `.invalidApiKey` and show `InvalidApiKeyView`
- All interactive elements hidden/disabled
- Localized strings: `error.invalidApiKey.title`, `error.invalidApiKey.message`

## Networking

- All API calls use async/await
- API key sent via `X-API-Key` header
- JSON uses snake_case key strategy
- OSLog logging via `SDKLogger` (subsystem: `com.swiftlyfeedback.sdk`)
- Cancelled requests (`CancellationError`, `URLError.cancelled`) silently re-thrown

## User Identification

- Uses iCloud user record ID when CloudKit available
- Falls back to local UUID stored in Keychain
- Safely checks CloudKit container before use

## Platform-Specific Behavior

| Feature | iOS | macOS |
|---------|-----|-------|
| Forms | Form with sections | Grid layout |
| Refresh | Pull-to-refresh | Refresh button (⌘R) |
| Submit | Standard | ⌘Return shortcut |

## Versioning

Follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes (removed/renamed public types, methods)
- **MINOR**: New features, backward-compatible additions
- **PATCH**: Bug fixes, no API changes

### Release Checklist

1. Update `CHANGELOG.md`
2. Create git tag: `git tag X.Y.Z`
3. Push: `git push feedbackkit-sdk X.Y.Z && git push origin X.Y.Z`
4. Create GitHub Release with CHANGELOG content

### SPM Constraints

```swift
.package(url: "...", from: "1.0.0")           // Recommended: 1.x.x
.package(url: "...", .upToNextMinor(from: "1.0.0"))  // 1.0.x only
.package(url: "...", exact: "1.0.0")          // Exact version
```

## Adding New Features

1. Add model in `Models/` if needed
2. Add API method to `APIClient.swift`
3. Expose via `SwiftlyFeedback.swift` public API
4. Create SwiftUI view in `Views/` if UI needed
