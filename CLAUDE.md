# CLAUDE.md - SwiftlyFeedbackKit

Swift client SDK with SwiftUI views for integrating feedback into iOS/macOS/visionOS apps.

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
```

## Code Patterns

### Models
- All models are `Codable`, `Sendable`, and `Equatable`
- Use `Identifiable` for SwiftUI list compatibility
- `FeedbackStatus.canVote` - Returns `false` for `completed`/`rejected` statuses

### Networking
- All API calls use async/await
- Errors are typed via `SwiftlyFeedbackError`
- API key is sent via `X-API-Key` header
- JSON encoding/decoding uses snake_case key strategy
- OSLog logging for debugging (subsystem: `com.swiftlyfeedback.sdk`)

### Error Handling
- `SwiftlyFeedbackError` cases: `invalidResponse`, `badRequest(message:)`, `unauthorized`, `notFound`, `conflict`, `serverError(statusCode:)`, `decodingError(underlying:)`
- Server error messages are parsed from response body when available

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

## Adding New Features

1. Add model in `Models/` if needed
2. Add API method to `APIClient.swift`
3. Expose via `SwiftlyFeedback.swift` public API
4. Create SwiftUI view in `Views/` if UI needed
