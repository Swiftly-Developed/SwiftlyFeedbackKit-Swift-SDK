# CLAUDE.md - Feedback Kit SDK

Swift SDK with SwiftUI views for integrating feedback into iOS/macOS/visionOS apps.

SwiftUI and other Apple UI work in this package uses the vendored `swiftui-pro` and `apple-hig` skills in [`.agents/skills/`](../.agents/skills/). See [AGENTS.md](../AGENTS.md).

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
- No watchOS target and no tvOS target

## Directory Structure

```
Plugins/GenerateStringCatalogSymbols/   # Build-tool plugin. No public Strings type.
Sources/SwiftlyFeedbackKit/
├── SwiftlyFeedback.swift        # Main entry point & configuration
├── KeychainHelper.swift         # Secure Keychain storage
├── UserIdentifier.swift         # Persistent user identifiers
├── Configuration/
│   ├── Config.swift             # SDK options
│   ├── FeedbackListStyle.swift  # .showcase (default) / .classic
│   ├── EnvironmentAPIKeys.swift # Multi-environment keys
│   └── Theme.swift              # Theme configuration
├── Utilities/
│   ├── BuildEnvironment.swift   # Build type detection
│   └── SDKLogger.swift          # Internal logging
├── Models/
│   ├── Feedback.swift           # Feedback model
│   ├── Comment.swift            # Comment model
│   ├── VoteResult.swift         # Vote result
│   ├── FeedbackListFilter.swift # Session-only status + category filter (client-side)
│   ├── FeedbackListBranch.swift # Which loaded state the list shows
│   └── ViewEvent.swift          # Event tracking
├── Networking/
│   ├── APIClient.swift          # HTTP client
│   └── SwiftlyFeedbackError.swift
├── Translation/                 # On-device translation (iOS/macOS; visionOS gets the no-op arm)
│   ├── FeedbackTranslator.swift # Batch queue + cache; owns the .translationTask configuration
│   ├── SourceLanguageDetector.swift
│   ├── TranslatableField.swift
│   ├── TranslatableUnit.swift
│   ├── TranslationAvailability.swift
│   ├── TranslationBatch.swift
│   ├── TranslationCache.swift
│   ├── LocaleLanguageDisplayName.swift
│   └── TranslationTaskViewModifier.swift  # The one platform-guarded wiring seam
├── Resources/
│   ├── Localizable.xcstrings    # String Catalog
│   └── PrivacyInfo.xcprivacy    # Privacy manifest
└── Views/
    ├── FeedbackListView.swift
    ├── FeedbackListSortFilterMenu.swift   # Sort, Status, Category, translation, Clear Filters
    ├── FeedbackListFilterSummaryRow.swift # "Filtered by … Clear"
    ├── FeedbackFilterEmptyStateView.swift # "No Matching Requests"
    ├── VotePresentation.swift             # One vote-control resolver for both list styles
    ├── Showcase/                          # The default list style (FEEDBACK01)
    │   ├── FeedbackShowcaseList.swift     # One inset-grouped section per request
    │   ├── FeedbackShowcaseCard.swift     # Status eyebrow, title, description, footer
    │   ├── FeedbackShowcaseVoteCapsule.swift  # Capsule, or a plain count when closed
    │   └── …                              # Eyebrow, glyph, footer, capsule style, skeleton
    ├── FeedbackRowView.swift              # Classic card
    ├── FeedbackDetailView.swift
    ├── SubmitFeedbackView.swift
    ├── VoteDialogView.swift
    ├── TranslationAffordanceView.swift    # "Translated from …" + Show original toggle
    ├── FeedbackListSkeletonView.swift
    ├── FeedbackCardSkeletonView.swift
    ├── FeedbackListRefreshIndicatorView.swift
    ├── FeedbackSearchEmptyStateView.swift
    ├── CommentsEmptyStateView.swift
    ├── InlineErrorView.swift
    └── InvalidApiKeyView.swift
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
| `.local` | localhost:8080 |
| `.development` | dev server |
| `.testflight` | staging server |
| `.production` | production server |

> **Note:** Add `TESTFLIGHT` to your target's **Active Compilation Conditions** in Build Settings for TestFlight builds.

### Alternative: Auto-Detection

```swift
// May be unreliable in some cases (uses AppTransaction with timeout)
SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
    debug: "sf_dev_...",          // Optional: development API. Nil uses the testflight key.
    testflight: "sf_staging_...",  // Required: staging server
    production: "sf_prod_..."      // Required: production server
))
```

> **Security:** Store API keys in Info.plist with xcconfig files, not hardcoded.

### Configuration Options

```swift
// Disable submission (e.g., for free users)
SwiftlyFeedback.configuration.allowFeedbackSubmission = false
SwiftlyFeedback.configuration.feedbackSubmissionDisabledMessage = "Upgrade to Pro!"

// Disable logging
SwiftlyFeedback.configuration.loggingEnabled = false

// Disable reader-side on-device translation of feedback content (default on;
// iOS/macOS only — the affordance is simply absent on visionOS and for
// unsupported language pairs)
SwiftlyFeedback.configuration.translationEnabled = false

// Event tracking
SwiftlyFeedback.view("feature_details", properties: ["id": "123"])
SwiftlyFeedback.configuration.enableAutomaticViewTracking = false
```

### Vote Notification Options

```swift
// Pre-set email (skips dialog when voting)
SwiftlyFeedback.configuration.userEmail = "user@example.com"

// Show email dialog when voting (only if userEmail is nil)
SwiftlyFeedback.configuration.showVoteEmailField = true

// Default state of "notify me" toggle
SwiftlyFeedback.configuration.voteNotificationDefaultOptIn = false

// Callback when email is set via vote dialog
SwiftlyFeedback.configuration.onUserEmailChanged = { email in
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
let feedback = try await SwiftlyFeedback.current?.getFeedback()
try await SwiftlyFeedback.current?.submitFeedback(title: "...", description: "...")
try await SwiftlyFeedback.current?.vote(for: feedbackId)
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
- `feedbackLimitReached(message:)` — a 402 that is not the metrics custom-events code. The Free 10-item cap does not return 402.
- `forbidden(message:)`, `rateLimited(message:)`
- `tierUpgradeRequired(code:message:)`, `measureNotAvailable(measure:message:)`

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

2.0.0 (tagged 14 October 2026 from `main`) and 3.0.0 are both major bumps: 2.0.0 removed and renamed theme, filter, and string API, and 3.0.0 moved to Swift 6 language mode and main-actor settings. `CHANGELOG.md` records the removed public `Strings` enum and the `GenerateStringCatalogSymbols` plugin under 3.0.0. Xcode asks a consumer to trust the plugin once. A non-interactive `xcodebuild` passes `-skipPackagePluginValidation`. A local package in this workspace is trusted automatically. The public repository's newest tag is 3.0.0. There is no 2.1.0 tag for this package.

### Release Checklist

1. Update `CHANGELOG.md`
2. Create git tag: `git tag X.Y.Z`
3. Push the tag to the mirror **by URL** (`https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Swift-SDK.git`) and to `origin` — the remote name `feedbackkit-sdk` is **not configured** in this checkout; run `git remote -v` before assuming it resolves ([`CLAUDE.md`](../CLAUDE.md) → Git Remotes & Branching).
4. Create GitHub Release with CHANGELOG content

### SPM Constraints

```swift
.package(url: "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Swift-SDK.git", from: "3.0.0")
.package(url: "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Swift-SDK.git", .upToNextMinor(from: "3.0.0"))
.package(url: "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Swift-SDK.git", exact: "3.0.0")
```

`from: "3.0.0"` resolves the 3.0.0 tag. `from: "2.0.0"` stays on 2.x and never resolves 3.0.0.

## Adding New Features

1. Add model in `Models/` if needed
2. Add API method to `APIClient.swift`
3. Expose via `SwiftlyFeedback.swift` public API
4. Create SwiftUI view in `Views/` if UI needed
