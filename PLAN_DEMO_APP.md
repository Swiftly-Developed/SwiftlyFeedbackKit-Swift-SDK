# SwiftlyFeedbackDemoApp Implementation Plan

## Overview

A simple demo app showcasing the SwiftlyFeedbackKit SDK with a focus on the feedback list view. The app will demonstrate best practices for iOS, iPadOS, and macOS while following Apple HIG and the AGENTS.md guidelines.

---

## Current State

- Demo app exists with basic Xcode template (`ContentView` showing "Hello, world!")
- SwiftlyFeedbackKit SDK provides:
  - `FeedbackListView` - ready-to-use list view
  - `FeedbackDetailView` - detail view with comments
  - `SubmitFeedbackView` - form for new feedback
  - Models: `Feedback`, `FeedbackStatus`, `FeedbackCategory`, `Comment`

## Key Constraints (from AGENTS.md)

- **Target**: iOS 26.0+, Swift 6.2+
- **Use**: `@Observable` with `@MainActor` (not `ObservableObject`)
- **Use**: `NavigationStack`, `Tab` API, `foregroundStyle()`, `clipShape(.rect(cornerRadius:))`
- **Avoid**: UIKit, GeometryReader, `cornerRadius()`, hard-coded padding/sizes
- **Avoid**: Force unwraps, GCD, computed properties for view decomposition

---

## Implementation Plan

### Step 1: Update SDK Views for Modern Swift (Required First)

The SDK currently uses deprecated patterns that conflict with AGENTS.md:
- `@StateObject` / `ObservableObject` -> `@State` / `@Observable`
- `fontWeight(.bold)` -> `bold()`
- Some views use computed properties instead of separate View structs

**Files to update in SwiftlyFeedbackKit:**
1. `FeedbackListView.swift` - Convert `FeedbackListViewModel` to `@Observable`
2. `FeedbackDetailView.swift` - Convert `FeedbackDetailViewModel` to `@Observable`
3. `SubmitFeedbackView.swift` - Convert `SubmitFeedbackViewModel` to `@Observable`
4. `FeedbackRowView.swift` - Extract `feedbackList` to separate view

### Step 2: Create Demo App Structure

```
SwiftlyFeedbackDemoApp/
├── App/
│   └── SwiftlyFeedbackDemoAppApp.swift   # Entry point with SDK configuration
├── Features/
│   └── Feedback/
│       ├── FeedbackTab.swift             # Main tab wrapping SDK's FeedbackListView
│       └── ConfigurationView.swift       # Settings for API key/URL (dev only)
├── Shared/
│   └── AppState.swift                    # @Observable app state
└── Resources/
    └── Assets.xcassets
```

### Step 3: App Entry Point

**SwiftlyFeedbackDemoAppApp.swift:**
- Configure `SwiftlyFeedback.shared` on launch
- Use environment to inject configuration
- Single `WindowGroup` scene

```swift
@main
struct SwiftlyFeedbackDemoAppApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
```

### Step 4: Main Content View with Platform Adaptation

**ContentView.swift:**
- Use `FeedbackListView` from SDK as primary content
- Platform-adaptive layout:
  - **iPhone**: Full-screen feedback list
  - **iPad**: NavigationSplitView with sidebar potential (future)
  - **Mac**: Window with toolbar, respects macOS patterns

```swift
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        FeedbackListView()
    }
}
```

### Step 5: App State

**AppState.swift:**
- `@Observable` class with `@MainActor`
- Stores user preferences (if any)
- Handles SDK initialization state

```swift
@MainActor
@Observable
final class AppState {
    var isConfigured = false
    var userId: String = UUID().uuidString

    init() {
        configureFeedbackSDK()
    }

    private func configureFeedbackSDK() {
        SwiftlyFeedback.configure(
            apiKey: "demo-api-key",
            userId: userId
        )
        isConfigured = true
    }
}
```

---

## Platform-Specific Considerations (Apple HIG)

### iOS (iPhone)
- Full-width list with edge-to-edge design
- Pull-to-refresh for feedback list
- Standard navigation bar with large title
- Sheet presentation for submit feedback

### iPadOS
- Same as iPhone for now (SDK handles this)
- Sidebar navigation potential for future tabs
- Support for keyboard shortcuts
- Pointer/trackpad support (automatic with SwiftUI)

### macOS
- Respects window sizing
- Menu bar integration (if needed)
- Native toolbar styling
- Keyboard navigation support

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `SwiftlyFeedbackDemoAppApp.swift` | Modify | Add SDK configuration |
| `ContentView.swift` | Modify | Replace template with FeedbackListView |
| `AppState.swift` | Create | Observable app state |
| `FeedbackListView.swift` (SDK) | Modify | Update to @Observable pattern |
| `FeedbackDetailView.swift` (SDK) | Modify | Update to @Observable pattern |
| `SubmitFeedbackView.swift` (SDK) | Modify | Update to @Observable pattern |
| `FeedbackRowView.swift` (SDK) | Modify | Minor style updates |

---

## Implementation Order

1. **Update SDK ViewModels** - Convert to `@Observable` pattern
2. **Create AppState** - New observable for demo app
3. **Update App Entry** - Configure SDK on launch
4. **Update ContentView** - Use FeedbackListView
5. **Test on all platforms** - iOS Simulator, iPad Simulator, Mac Catalyst/native

---

## Out of Scope (Keeping it Simple)

- Multiple tabs (just feedback for now)
- User authentication
- Push notifications
- Offline support
- Analytics
- Deep linking

---

## Testing

- Unit tests for AppState configuration
- UI tests for basic feedback list interaction
- Manual testing on iOS, iPadOS, macOS

---

## Decisions Made

1. **iOS target**: iOS 26.0+
2. **SDK updates**: Convert to `@Observable` pattern
3. **Configuration**: Hardcode API URL (localhost:8080) and API key
