# CLAUDE.md - Feedback Kit Demo App

Demo application showcasing the Feedback Kit SDK integration.

## Build & Test

```bash
# Build via workspace
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackDemoApp -sdk iphonesimulator -configuration Debug

# Test
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackDemoApp test -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Directory Structure

```
SwiftlyFeedbackDemoApp/
├── SwiftlyFeedbackDemoAppApp.swift   # App entry point with SDK configuration
├── ContentView.swift                  # Platform-adaptive navigation (TabView iOS, NavigationSplitView macOS)
├── Models/
│   └── AppSettings.swift             # @Observable settings class with UserDefaults persistence
└── Views/
    ├── HomeView.swift                # Welcome screen explaining SwiftlyFeedback features
    └── ConfigurationView.swift       # Settings form for user profile and SDK configuration
```

## App Structure

### iOS (TabView)
Three tabs: Home, Feedback, Settings

### macOS (NavigationSplitView)
Sidebar navigation with: Home, Feedback, Settings
- Minimum window size: 800x500
- Default window size: 1000x700

### Screens

1. **Home** - Welcome screen with hero section, feature highlights, and getting started guide
2. **Feedback** - SDK's built-in `FeedbackListView` for browsing and submitting feedback
3. **Settings** - Configuration screen for:
   - User profile (email, name, custom ID)
   - Subscription settings (amount and billing cycle for MRR tracking)
   - Permissions (allow/disallow feedback submission with custom message)
   - SDK behavior options (vote undo, comment section, email field)
   - Display options (badges, vote count, description expansion)

## SDK Features Demonstrated

### Configuration at Launch
```swift
SwiftlyFeedback.configure(with: "your_api_key")
SwiftlyFeedback.theme.primaryColor = .color(.blue)
SwiftlyFeedback.theme.statusColors.completed = .green
```

### User Identification
```swift
SwiftlyFeedback.updateUser(customID: "user123")
```

### Payment/Subscription Tracking
```swift
SwiftlyFeedback.updateUser(payment: .monthly(9.99))
SwiftlyFeedback.clearUserPayment()
```

### SDK Configuration Options
```swift
SwiftlyFeedback.config.allowUndoVote = true
SwiftlyFeedback.config.showCommentSection = true
SwiftlyFeedback.config.showEmailField = true
SwiftlyFeedback.config.showStatusBadge = true
SwiftlyFeedback.config.showCategoryBadge = true
SwiftlyFeedback.config.showVoteCount = true
SwiftlyFeedback.config.expandDescriptionInList = false

// Permission controls
SwiftlyFeedback.config.allowFeedbackSubmission = true  // Disable for free users
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro!"

// Logging
SwiftlyFeedback.config.loggingEnabled = false  // Reduce console clutter
```

## Settings Persistence

The `AppSettings` class uses `@Observable` and persists all settings to `UserDefaults`:
- Settings are automatically loaded on app launch
- Changes are saved immediately via `didSet` observers
- SDK configuration is applied on init and when settings change
- Use `Bindable(settings).propertyName` for bindings in views

## Platform-Specific Notes

### macOS
- Uses `NavigationSplitView` with sidebar `List` and `NavigationLink`
- Window constraints set via `.frame(minWidth:minHeight:)` and `.defaultSize()`

### iOS
- Uses `TabView` with modern `Tab` API
- Each tab wraps content in `NavigationStack` where needed

## Development Notes

- Depends on SwiftlyFeedbackKit package
- Server must be running for full functionality
- Update API key for your environment
- Uses modern SwiftUI patterns: @Observable, Bindable()
- Platform conditionals: `#if os(macOS)` / `#if os(iOS)`
