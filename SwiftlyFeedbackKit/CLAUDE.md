# CLAUDE.md - Feedback Kit SDK

Swift client SDK with SwiftUI views for integrating feedback into iOS/macOS/visionOS apps.

## Version History

| Version | Date | Type | Notes |
|---------|------|------|-------|
| 1.0.0 | 2026-01-13 | Initial | First public release |

See [CHANGELOG.md](./CHANGELOG.md) for detailed release notes.

## Build & Test

```bash
# Build
swift build

# Test
swift test
```

## Platforms

- iOS 15+
- macOS 12+
- visionOS 1+

## Directory Structure

```
Sources/SwiftlyFeedbackKit/
├── SwiftlyFeedback.swift     # Main SDK entry point & configuration
├── Configuration/
│   └── Config.swift          # SDK configuration options
├── Models/
│   ├── Feedback.swift        # Feedback model
│   ├── Comment.swift         # Comment model
│   ├── VoteResult.swift      # Vote result model
│   └── ViewEvent.swift       # View event model & predefined types
├── Networking/
│   ├── APIClient.swift       # HTTP client for API calls
│   └── SwiftlyFeedbackError.swift  # Error types
└── Views/
    ├── FeedbackListView.swift      # List of all feedback
    ├── FeedbackRowView.swift       # Single feedback row
    ├── FeedbackDetailView.swift    # Feedback detail with comments
    └── SubmitFeedbackView.swift    # Form to submit new feedback
```

## SDK Usage

```swift
import SwiftlyFeedbackKit

// Configure once at app launch
SwiftlyFeedback.configure(
    apiKey: "sf_your_api_key",
    userId: "unique_user_id",
    baseURL: URL(string: "https://your-server.com/api/v1")!
)

// Use pre-built SwiftUI views
FeedbackListView()
SubmitFeedbackView()
FeedbackDetailView(feedback: someFeedback)

// Or use the API directly
let feedback = try await SwiftlyFeedback.shared?.getFeedback()
try await SwiftlyFeedback.shared?.submitFeedback(title: "...", description: "...")
try await SwiftlyFeedback.shared?.vote(for: feedbackId)

// Track custom view events (any event name)
SwiftlyFeedback.view("onboarding_step_1")
SwiftlyFeedback.view("purchase_completed", properties: ["amount": "9.99"])

// Predefined views (automatically tracked when views appear)
SwiftlyFeedback.view(.feedbackList)
SwiftlyFeedback.view(.feedbackDetail)
SwiftlyFeedback.view(.submitFeedback)

// Disable automatic view tracking
SwiftlyFeedback.config.enableAutomaticViewTracking = false

// Restrict feedback submission (e.g., for free users)
SwiftlyFeedback.config.allowFeedbackSubmission = false
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro to submit feedback!"

// Disable SDK logging to reduce console clutter
SwiftlyFeedback.config.loggingEnabled = false

// Vote email notifications (see Vote Notifications section below)
SwiftlyFeedback.config.userEmail = "user@example.com"
SwiftlyFeedback.config.showVoteEmailField = true
SwiftlyFeedback.config.voteNotificationDefaultOptIn = false
```

## Code Patterns

### Models
- All models are `Codable`, `Sendable`, and `Equatable`
- Use `Identifiable` for SwiftUI list compatibility
- `FeedbackStatus` - Enum with cases: `pending`, `approved`, `inProgress`, `testflight`, `completed`, `rejected`
- `FeedbackStatus.canVote` - Returns `false` for `completed`/`rejected` statuses
- `FeedbackStatus.displayName` - User-friendly name for display
- `Feedback.mergedIntoId` - Points to primary feedback if this item was merged
- `Feedback.isMerged` - Computed property to check if feedback was merged
- `Feedback.mergedFeedbackIds` - Array of IDs merged into this feedback (for primary)

### Networking
- All API calls use async/await
- Errors are typed via `SwiftlyFeedbackError`
- API key is sent via `X-API-Key` header
- JSON encoding/decoding uses snake_case key strategy
- OSLog logging via `SDKLogger` utility (subsystem: `com.swiftlyfeedback.sdk`)
- Logging can be disabled via `SwiftlyFeedback.config.loggingEnabled = false`
- Request cancellation is handled gracefully - `CancellationError` and `URLError.cancelled` are silently re-thrown without logging

### Error Handling
- `SwiftlyFeedbackError` cases: `invalidResponse`, `badRequest(message:)`, `unauthorized`, `invalidApiKey`, `notFound`, `conflict`, `serverError(statusCode:)`, `networkError(underlying:)`, `decodingError(underlying:)`
- Server error messages are parsed from response body when available
- Cancelled requests do not show error alerts to users
- `SwiftlyFeedbackError` conforms to `Equatable` for pattern matching

### Invalid API Key Handling
When the server returns a 401 with "Invalid API key" message:
- SDK throws `.invalidApiKey` error (distinct from generic `.unauthorized`)
- Views detect this and show `InvalidApiKeyView` - a `ContentUnavailableView` with localized message
- All toolbar buttons and interactive elements are hidden/disabled
- Further API calls are blocked via `hasInvalidApiKey` guard
- Localized strings: `error.invalidApiKey.title`, `error.invalidApiKey.message`
- Message tells users to contact the app developers for assistance

### User Identification
- Uses iCloud user record ID when CloudKit is available and properly configured
- Falls back to local UUID stored in Keychain when CloudKit is unavailable
- Safely checks for CloudKit container configuration before attempting to use it

### Views
- Views use `@State` and `@Environment` for state management
- Follow AGENTS.md guidelines for SwiftUI patterns
- Use `#Preview` macro for previews
- Platform-specific adaptations:
  - macOS: Uses Grid layout for forms, refresh button (⌘R), submit shortcut (⌘Return)
  - iOS: Uses Form with sections, keyboard-aware scrolling
- `FeedbackCategory.iconName` provides SF Symbol names for each category
- `VoteButton` is disabled and dimmed for feedback with non-votable status

### FeedbackListView Sorting & Animation

The `FeedbackListView` includes built-in sorting and smooth animations:

**Sort Options (`FeedbackSortOption` enum):**
| Option | Description |
|--------|-------------|
| `.votes` | Highest vote count first (default) |
| `.newest` | Most recently created first |
| `.oldest` | Oldest first |

**Features:**
- Sort picker in toolbar menu (combined with status filter if enabled)
- Sorting is applied client-side after fetching
- Smooth `.smooth` animation when list order changes
- Items animate with `.opacity.combined(with: .move(edge: .top))` transition

**Implementation:**
- `FeedbackListViewModel.selectedSort` - Current sort option (default: `.votes`)
- `sortFeedback()` - Applies sort with `withAnimation(.smooth)`
- Animation value: `.animation(.smooth, value: viewModel.feedbackItems)`

### Request Deduplication
- `FeedbackListViewModel` tracks in-flight requests via `loadTask` property
- New requests cancel any pending request to prevent race conditions
- `loadFeedbackIfNeeded()` prevents duplicate initial loads (used by `.task` modifier)
- `loadFeedback()` always executes (used by `.refreshable` and filter changes)
- Cancelled requests are silently ignored - no error alerts shown to users

## Vote Notifications

Users can optionally provide their email when voting to receive status change notifications.

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `userEmail` | `nil` | Pre-configured email. If set, votes use it automatically (no dialog shown) |
| `showVoteEmailField` | `true` | Show email dialog when voting (only if `userEmail` is nil) |
| `voteNotificationDefaultOptIn` | `false` | Default state of "notify me" toggle |
| `onUserEmailChanged` | `nil` | Callback when email is set via vote dialog |

### Behavior

1. **Email configured** (`userEmail` set): Votes automatically use the email, no dialog shown
2. **No email + dialog enabled**: User sees dialog to optionally enter email when voting
3. **No email + dialog disabled**: Vote submitted without email

### Syncing Email from Vote Dialog

When a user enters their email via the vote dialog, it's saved to `SwiftlyFeedback.config.userEmail`. To sync this back to your app's settings:

```swift
SwiftlyFeedback.config.onUserEmailChanged = { email in
    // Save to UserDefaults or your settings system
    UserDefaults.standard.set(email ?? "", forKey: "userEmail")
}
```

### Vote Dialog UI

The vote dialog is platform-specific following Apple HIG:
- **iOS/iPadOS**: Sheet with Form, navigation bar buttons (Skip/Vote)
- **macOS**: VStack layout with button bar (Skip left, Vote right)

Both list view and detail view voting trigger the same dialog when email is not configured.

## Adding New Features

1. Add model in `Models/` if needed
2. Add API method to `APIClient.swift`
3. Expose via `SwiftlyFeedback.swift` public API
4. Create SwiftUI view in `Views/` if UI needed
