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
├── Models/
│   ├── Feedback.swift        # Feedback model
│   ├── Comment.swift         # Comment model
│   └── VoteResult.swift      # Vote result model
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
```

## Code Patterns

### Models
- All models are `Codable`, `Sendable`, and `Equatable`
- Use `Identifiable` for SwiftUI list compatibility

### Networking
- All API calls use async/await
- Errors are typed via `SwiftlyFeedbackError`
- API key is sent via `X-API-Key` header

### Views
- Views use `@State` and `@Environment` for state management
- Follow AGENTS.md guidelines for SwiftUI patterns
- Use `#Preview` macro for previews

## Adding New Features

1. Add model in `Models/` if needed
2. Add API method to `APIClient.swift`
3. Expose via `SwiftlyFeedback.swift` public API
4. Create SwiftUI view in `Views/` if UI needed
