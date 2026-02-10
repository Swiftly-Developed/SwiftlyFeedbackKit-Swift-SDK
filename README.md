![FeedbackKit Banner](docs/images/banner.png)

# <img src="docs/images/logo.png" width="32" height="32" alt="FeedbackKit Logo" style="vertical-align: middle;"> FeedbackKit

In-app feedback collection for iOS, macOS, and visionOS.

![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20visionOS-blue.svg)
![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg)

FeedbackKit is a Swift SDK that lets you collect, manage, and respond to user feedback directly within your app. Users can submit feature requests, report bugs, vote on ideas, and see what's being worked on — all without leaving your app.

## Multi-Platform SDKs

FeedbackKit is available for multiple platforms:

| Platform | Package | Install |
|----------|---------|---------|
| **Swift** (iOS/macOS/visionOS) | This package | Swift Package Manager |
| **JavaScript** | [feedbackkit-js](https://www.npmjs.com/package/feedbackkit-js) | `npm install feedbackkit-js` |
| **React Native** | [feedbackkit-react-native](https://www.npmjs.com/package/feedbackkit-react-native) | `npm install feedbackkit-react-native` |
| **Flutter** | [feedbackkit_flutter](https://pub.dev/packages/feedbackkit_flutter) | `flutter pub add feedbackkit_flutter` |
| **Kotlin/Android** | [com.getfeedbackkit:feedbackkit](https://central.sonatype.com/artifact/com.getfeedbackkit/feedbackkit) | Maven Central |

## Features

- **Ready-to-use SwiftUI views** — Drop-in feedback list, submission form, and detail views
- **Voting system** — Let users upvote feedback to surface popular requests
- **Comments** — Two-way communication between you and your users
- **Status tracking** — Show users the progress of their feedback (pending → approved → in progress → completed)
- **Categories** — Organize feedback by type: feature requests, bug reports, improvements
- **Feedback merging** — Duplicate feedback items can be merged from the admin side
- **Rejection reasons** — Explain why feedback was rejected with a visible reason
- **Theming** — Customize primary, secondary, and tertiary colors to match your app's design
- **Dark mode** — Full support for light and dark appearances
- **Multi-platform** — Native support for iOS, macOS, and visionOS
- **Event tracking** — Built-in analytics for user engagement
- **MRR tracking** — Associate feedback with customer revenue
- **Localization** — Full String Catalog support for translations

## Requirements

- iOS 26+ / macOS 26+ / visionOS 26+
- Swift 6.2+
- Xcode 26+

## Installation

### Swift Package Manager

Add FeedbackKit to your project using Xcode:

1. Go to **File → Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/Swiftly-Developed/SwiftlyFeedbackKit
   ```
3. Select the version and click **Add Package**

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit", from: "1.0.0")
]
```

## Quick Start

Get up and running in 3 steps:

### 1. Import and Configure

```swift
import SwiftlyFeedbackKit

@main
struct MyApp: App {
    init() {
        #if DEBUG
        SwiftlyFeedback.configure(environment: .development, key: "your-dev-api-key")
        #elseif TESTFLIGHT
        SwiftlyFeedback.configure(environment: .testflight, key: "your-staging-api-key")
        #else
        SwiftlyFeedback.configure(environment: .production, key: "your-prod-api-key")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

> **Note:** To use the `TESTFLIGHT` flag, add it to your project's build settings under **Active Compilation Conditions** for your TestFlight build configuration.

### 2. Present the Feedback List

```swift
import SwiftlyFeedbackKit

struct ContentView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showFeedback = true
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackListView()
        }
    }
}
```

### 3. That's it!

Your users can now browse existing feedback, submit new ideas, and vote on what matters most.

<img src="docs/images/feedback-list-ios.png" width="300" alt="Feedback List">

## Configuration

### Environments

| Environment | Server |
|-------------|--------|
| `.development` | `http://localhost:8080/api/v1` |
| `.testflight` | `https://api.feedbackkit.testflight.swiftly-developed.com/api/v1` |
| `.production` | `https://api.feedbackkit.prod.swiftly-developed.com/api/v1` |

### API Key Setup

Get your API key from the [FeedbackKit Admin app](https://www.getfeedbackkit.com):

1. Create or select a project
2. Go to **Project Settings → API Key**
3. Copy the key (starts with `sf_`)

### Configuration Methods

```swift
// Recommended: Explicit environment configuration
#if DEBUG
SwiftlyFeedback.configure(environment: .development, key: "your-dev-key")
#elseif TESTFLIGHT
SwiftlyFeedback.configure(environment: .testflight, key: "your-staging-key")
#else
SwiftlyFeedback.configure(environment: .production, key: "your-prod-key")
#endif

// Alternative: Auto-detection
SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
    debug: "your-dev-key",        // Optional
    testflight: "your-staging-key",
    production: "your-prod-key"
))
```

> **Note:** `configureAuto(with:)` (single key) is deprecated. Use `configureAuto(keys:)` for multi-environment support.

#### Setting Up the TESTFLIGHT Flag

To use the `#if TESTFLIGHT` compiler flag:

1. In Xcode, go to your target's **Build Settings**
2. Search for **Active Compilation Conditions**
3. Add `TESTFLIGHT` to your TestFlight/Staging build configuration

#### Testing TestFlight Behavior in Debug

```swift
#if DEBUG
BuildEnvironment.simulateTestFlight = true
#endif
```

## Views

FeedbackKit provides three main SwiftUI views that handle all the UI and API interactions for you.

### FeedbackListView

Displays all feedback with sorting and filtering options.

```swift
// Basic usage
FeedbackListView()

// With custom instance
FeedbackListView(swiftlyFeedback: customInstance)
```

**Features:**
- Sort by votes (default), newest, or oldest
- Filter by status (pending, approved, in progress, etc.)
- Pull-to-refresh on iOS, refresh button (⌘R) on macOS
- Add feedback button (configurable)
- Empty state with call-to-action
- Request deduplication (prevents duplicate API calls)

**Sort Options:**

| Option | Description |
|--------|-------------|
| `.votes` | Highest vote count first (default) |
| `.newest` | Most recently created first |
| `.oldest` | Oldest first |

![Feedback List on macOS](docs/images/feedback-list-mac.png)

### SubmitFeedbackView

A form for users to submit new feedback.

```swift
// Basic usage
SubmitFeedbackView()

// With dismiss callback
SubmitFeedbackView {
    // Called when the view is dismissed
    print("Feedback submitted or cancelled")
}
```

**Features:**
- Title and description fields
- Category picker (Feature Request, Bug Report, Improvement, Other)
- Optional email field
- Platform-optimized layouts (form on iOS, grid on macOS)
- Loading state during submission
- Keyboard shortcut on macOS (⌘Return to submit)

<table>
<tr>
<td><img src="docs/images/submit-feedback-ios.png" width="300" alt="Submit Feedback iOS"></td>
<td><img src="docs/images/submit-feedback-mac.png" width="400" alt="Submit Feedback macOS"></td>
</tr>
</table>

### FeedbackDetailView

Shows detailed information about a single feedback item.

```swift
FeedbackDetailView(feedback: selectedFeedback)
```

**Features:**
- Full title and description
- Status and category badges
- Vote button with count
- Comments section (admin comments styled differently)
- Rejection reason display (when status is rejected)
- Submission date

### InvalidApiKeyView

Automatically shown when an invalid API key is detected. All interactive elements are hidden/disabled. No configuration needed.

## Customization

### Feature Toggles

Control which UI elements are visible:

```swift
// Voting
SwiftlyFeedback.config.allowUndoVote = true          // Allow removing votes
SwiftlyFeedback.config.showVoteCount = true          // Show vote counts

// Badges
SwiftlyFeedback.config.showStatusBadge = true        // Show status badges
SwiftlyFeedback.config.showCategoryBadge = true      // Show category badges

// Form fields
SwiftlyFeedback.config.showEmailField = true         // Show email in submit form

// Comments
SwiftlyFeedback.config.showCommentSection = true     // Show comments in detail view

// List behavior
SwiftlyFeedback.config.expandDescriptionInList = false  // Expand descriptions in list

// Buttons
SwiftlyFeedback.config.buttons.addButton.display = true
SwiftlyFeedback.config.buttons.addButton.bottomPadding = 16
SwiftlyFeedback.config.buttons.segmentedControl.display = true
```

### Disable Feedback Submission

Useful for paywalls or read-only modes:

```swift
SwiftlyFeedback.config.allowFeedbackSubmission = false
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro to submit feedback"
```

### Vote Notifications

Let users receive email notifications when feedback they voted on changes status:

```swift
// Pre-set user email (votes use this automatically, no dialog shown)
SwiftlyFeedback.config.userEmail = "user@example.com"

// Show email dialog when voting (only shown if userEmail is nil)
SwiftlyFeedback.config.showVoteEmailField = true  // default: true

// Default opt-in state for the "notify me" toggle
SwiftlyFeedback.config.voteNotificationDefaultOptIn = false  // default: false

// Sync email back to your app when user enters it via vote dialog
SwiftlyFeedback.config.onUserEmailChanged = { email in
    UserDefaults.standard.set(email ?? "", forKey: "userEmail")
}
```

**Behavior:**
- If `userEmail` is set: Votes automatically use that email, no dialog shown
- If `userEmail` is nil and `showVoteEmailField` is true: Users see a dialog to optionally enter email
- If `userEmail` is nil and `showVoteEmailField` is false: Votes submitted without email

Users who opt-in receive emails when feedback status changes (approved, in progress, completed, etc.) with a one-click unsubscribe link.

### Theming

Customize colors to match your app:

```swift
// Primary color (buttons, highlights)
SwiftlyFeedback.theme.primaryColor = .color(.blue)

// Secondary and tertiary colors
SwiftlyFeedback.theme.secondaryColor = .color(.gray)
SwiftlyFeedback.theme.tertiaryColor = .color(.gray.opacity(0.2))

// Adaptive colors for dark mode
SwiftlyFeedback.theme.primaryColor = .adaptive(
    light: .blue,
    dark: .cyan
)

// Use system accent color
SwiftlyFeedback.theme.primaryColor = .default
```

#### Status Colors

Customize the color for each feedback status:

```swift
SwiftlyFeedback.theme.statusColors.pending = .gray
SwiftlyFeedback.theme.statusColors.approved = .blue
SwiftlyFeedback.theme.statusColors.inProgress = .orange
SwiftlyFeedback.theme.statusColors.testflight = .cyan
SwiftlyFeedback.theme.statusColors.completed = .green
SwiftlyFeedback.theme.statusColors.rejected = .red
```

#### Category Colors

Customize the color for each feedback category:

```swift
SwiftlyFeedback.theme.categoryColors.featureRequest = .purple
SwiftlyFeedback.theme.categoryColors.bugReport = .red
SwiftlyFeedback.theme.categoryColors.improvement = .teal
SwiftlyFeedback.theme.categoryColors.other = .gray
```

#### Theme Examples

<table>
<tr>
<td><img src="docs/images/orange.png" width="200" alt="Orange Theme"></td>
<td><img src="docs/images/green.png" width="200" alt="Green Theme"></td>
<td><img src="docs/images/pink.png" width="200" alt="Pink Theme"></td>
</tr>
<tr>
<td><img src="docs/images/purple.png" width="200" alt="Purple Theme"></td>
<td><img src="docs/images/red.png" width="200" alt="Red Theme"></td>
<td><img src="docs/images/mint.png" width="200" alt="Mint Theme"></td>
</tr>
</table>

### Dark Mode

FeedbackKit automatically adapts to the system appearance. Use adaptive colors for custom theming:

```swift
SwiftlyFeedback.theme.primaryColor = .adaptive(
    light: .blue,
    dark: .cyan
)
```

<table>
<tr>
<td><img src="docs/images/light.png" width="300" alt="Light Mode"></td>
<td><img src="docs/images/dark.png" width="300" alt="Dark Mode"></td>
</tr>
</table>

## Direct API Access

For custom implementations, access the API directly:

### Fetching Feedback

```swift
// Get all feedback
let allFeedback = try await SwiftlyFeedback.shared?.getFeedback()

// Filter by status
let pending = try await SwiftlyFeedback.shared?.getFeedback(status: .pending)

// Filter by category
let bugs = try await SwiftlyFeedback.shared?.getFeedback(category: .bugReport)

// Combine filters
let pendingBugs = try await SwiftlyFeedback.shared?.getFeedback(
    status: .pending,
    category: .bugReport
)

// Get single feedback by ID
let feedback = try await SwiftlyFeedback.shared?.getFeedback(id: feedbackId)
```

### Submitting Feedback

```swift
let feedback = try await SwiftlyFeedback.shared?.submitFeedback(
    title: "Dark mode support",
    description: "It would be great to have a dark mode option...",
    category: .featureRequest,
    email: "user@example.com"  // Optional
)
```

### Voting

```swift
// Vote for feedback
let result = try await SwiftlyFeedback.shared?.vote(for: feedbackId)
print("New vote count: \(result.voteCount)")

// Vote with email for status notifications
let result = try await SwiftlyFeedback.shared?.vote(
    for: feedbackId,
    email: "user@example.com",
    notifyStatusChange: true
)

// Remove vote (if allowUndoVote is enabled)
let result = try await SwiftlyFeedback.shared?.unvote(for: feedbackId)
```

### Comments

```swift
// Get comments for feedback
let comments = try await SwiftlyFeedback.shared?.getComments(for: feedbackId)

// Add a comment
let comment = try await SwiftlyFeedback.shared?.addComment(
    to: feedbackId,
    content: "Thanks for the suggestion!"
)
```

## Models

### Feedback

```swift
public struct Feedback: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String
    public let status: FeedbackStatus
    public let category: FeedbackCategory
    public let userId: String
    public let userEmail: String?
    public let voteCount: Int
    public let hasVoted: Bool
    public let commentCount: Int
    public let rejectionReason: String?
    public let mergedIntoId: UUID?
    public let mergedAt: Date?
    public let mergedFeedbackIds: [UUID]?
    public let createdAt: Date?
    public let updatedAt: Date?

    public var isMerged: Bool { mergedIntoId != nil }
}
```

### FeedbackStatus

| Status | Display Name | Can Vote | Icon |
|--------|-------------|----------|------|
| `pending` | Pending | Yes | — |
| `approved` | Approved | Yes | — |
| `inProgress` | In Progress | Yes | — |
| `testflight` | TestFlight | Yes | — |
| `completed` | Completed | No | — |
| `rejected` | Rejected | No | — |

### FeedbackCategory

| Category | Icon | Use Case |
|----------|------|----------|
| `featureRequest` | `lightbulb` | New functionality ideas |
| `bugReport` | `ladybug` | Issues and problems |
| `improvement` | `arrow.up.circle` | Enhancements to existing features |
| `other` | `ellipsis.circle` | General feedback |

### Comment

```swift
public struct Comment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let content: String
    public let userId: String
    public let isAdmin: Bool        // Admin comments have special styling
    public let createdAt: Date?
}
```

### VoteResult

```swift
public struct VoteResult: Codable, Sendable {
    public let feedbackId: UUID
    public let voteCount: Int
    public let hasVoted: Bool
}
```

## User Identification

FeedbackKit automatically manages user identity with the following priority:

1. **Custom user ID** — If set via `updateUser(customID:)`
2. **Existing stored ID** — Previously generated/set ID from Keychain
3. **iCloud user record ID** — If CloudKit is available
4. **Local UUID** — Generated and stored in Keychain (survives app reinstalls)

### Custom User ID

```swift
// Set a custom user ID (e.g., after login)
SwiftlyFeedback.updateUser(customID: "user_12345")
```

### Clearing User ID

```swift
// Clear the stored user ID from Keychain
UserIdentifier.clearUserId()
```

### MRR Tracking

Track Monthly Recurring Revenue to prioritize feedback from paying customers:

```swift
// Set user's subscription value
SwiftlyFeedback.updateUser(payment: .monthly(9.99))
SwiftlyFeedback.updateUser(payment: .yearly(99.99))
SwiftlyFeedback.updateUser(payment: .weekly(2.31))
SwiftlyFeedback.updateUser(payment: .quarterly(29.97))

// Clear on subscription cancellation
SwiftlyFeedback.clearUserPayment()
```

MRR data appears in the Admin app, allowing you to sort and filter feedback by customer value.

## Event Tracking

FeedbackKit includes built-in analytics to track user engagement.

### Automatic Tracking

By default, view events are tracked automatically when users open SDK screens:

- `feedback_list` — When FeedbackListView appears
- `feedback_detail` — When FeedbackDetailView appears
- `submit_feedback` — When SubmitFeedbackView appears

Disable automatic tracking:

```swift
SwiftlyFeedback.config.enableAutomaticViewTracking = false
```

### Custom Events

Track custom events in your app:

```swift
// Simple event
SwiftlyFeedback.view("onboarding_completed")

// Event with properties
SwiftlyFeedback.view("purchase_completed", properties: [
    "product_id": "pro_monthly",
    "price": "9.99"
])

// Predefined SDK views
SwiftlyFeedback.view(.feedbackList)
SwiftlyFeedback.view(.feedbackDetail)
SwiftlyFeedback.view(.submitFeedback)
```

## Localization

FeedbackKit uses String Catalogs for localization. All user-facing strings can be customized or translated.

To override SDK strings in your app:

1. Create a `Localizable.xcstrings` file in your project
2. Add the SDK's string keys with your custom translations
3. The SDK will use your translations automatically

## Error Handling

FeedbackKit provides typed errors for handling failures:

```swift
do {
    let feedback = try await SwiftlyFeedback.shared?.submitFeedback(
        title: "My idea",
        description: "Details...",
        category: .featureRequest
    )
} catch let error as SwiftlyFeedbackError {
    switch error {
    case .invalidApiKey:
        print("Check your API key")
    case .feedbackLimitReached(let message):
        print("Limit reached: \(message ?? "Upgrade your plan")")
    case .networkError(let underlying):
        print("Network issue: \(underlying)")
    case .unauthorized:
        print("Authentication failed")
    case .notFound:
        print("Feedback not found")
    case .badRequest(let message):
        print("Bad request: \(message ?? "")")
    case .conflict:
        print("Conflict (e.g., duplicate vote)")
    case .serverError(let statusCode):
        print("Server error: \(statusCode)")
    case .decodingError(let underlying):
        print("Failed to decode response: \(underlying)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

### Invalid API Key

When an invalid API key is detected, the SDK automatically shows an error state in views with all interactive elements disabled.

### Feedback Limit Reached

When hitting subscription tier limits (e.g., 10 feedback items on the Free tier), a `feedbackLimitReached` error is thrown with a descriptive message.

## Logging

FeedbackKit logs API requests and responses using OSLog for debugging:

```swift
// Disable logging in production
SwiftlyFeedback.config.loggingEnabled = false
```

Logs appear in Console.app under the subsystem `com.swiftlyfeedback.sdk` with category `SDK`.

## Build Environment

Detect the current build environment:

```swift
BuildEnvironment.isDebug              // Running in Xcode
BuildEnvironment.isTestFlight         // Running in TestFlight
BuildEnvironment.isAppStore           // Running from App Store
BuildEnvironment.canShowTestingFeatures  // Debug or TestFlight
BuildEnvironment.displayName          // Human-readable name
```

## Platform Differences

### iOS
- Form-based submit view with sections
- Pull-to-refresh in feedback list
- Sheet presentation recommended

### macOS
- Grid-based submit view
- Minimum window size enforced (400x350)
- ⌘Return shortcut to submit
- ⌘R shortcut to refresh
- Window or popover presentation

### visionOS
- Adapted for spatial computing
- Supports all standard interactions

## Example App

Check out the [SwiftlyFeedbackDemoApp](../SwiftlyFeedbackDemoApp) for a complete integration example showing:

- Basic setup and configuration
- Presenting feedback views
- Custom theming
- Event tracking
- User identification

## Admin App

Manage your feedback from the [FeedbackKit Admin app](https://www.getfeedbackkit.com):

- Review and respond to feedback
- Update statuses
- Merge duplicate feedback
- View analytics and MRR data
- Configure integrations (Slack, GitHub, Linear, Notion, and more)
- Manage team members

## Support

- **Website:** [getfeedbackkit.com](https://www.getfeedbackkit.com)
- **Issues:** [GitHub Issues](https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/issues)
- **Email:** info@swiftly-workspace.com

## License

FeedbackKit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
