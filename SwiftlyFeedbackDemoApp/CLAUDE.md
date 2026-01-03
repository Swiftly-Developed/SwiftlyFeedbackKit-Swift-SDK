# CLAUDE.md - SwiftlyFeedbackDemoApp

Demo application showcasing SwiftlyFeedbackKit SDK integration.

## Build & Test

```bash
# Build via workspace
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackDemoApp -sdk iphonesimulator -configuration Debug

# Test
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackDemoApp test -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Directory Structure

```
SwiftlyFeedbackDemoApp/
├── SwiftlyFeedbackDemoAppApp.swift  # App entry point with SDK configuration
└── ContentView.swift                 # Main view demonstrating SDK usage
```

## Purpose

This app demonstrates how to:

1. Configure SwiftlyFeedbackKit at app launch
2. Display the feedback list using `FeedbackListView`
3. Allow users to submit feedback via `SubmitFeedbackView`
4. Show feedback details with `FeedbackDetailView`

## SDK Configuration Example

```swift
import SwiftlyFeedbackKit

@main
struct SwiftlyFeedbackDemoAppApp: App {
    init() {
        SwiftlyFeedback.configure(
            apiKey: "your_api_key",
            userId: "demo_user",
            baseURL: URL(string: "http://localhost:8080/api/v1")!
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Development Notes

- Depends on SwiftlyFeedbackKit package
- Server must be running for full functionality
- Update API key and baseURL for your environment
- macOS sandbox enabled with network client capability (incoming/outgoing connections)
