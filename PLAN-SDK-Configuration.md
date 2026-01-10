# SDK Configuration Refactoring Plan

## Problem Statement

The SDK's `configureAuto(with:)` method auto-detects build environment and switches servers. This is wrong for external clients because:

1. **API keys are server-specific** - A key created on Production won't work on other servers
2. **External clients only have Production access** - They create projects via the App Store Admin app
3. **Client's DEBUG/TestFlight builds should still use Production** - That's where their project exists

## Correct Behavior

| User | Xcode (DEBUG) | TestFlight | App Store |
|------|---------------|------------|-----------|
| **External SDK client** | Production | Production | Production |
| **Feedback Kit team** | Localhost | Staging | Production |

## Proposed Solution

### API Design

```swift
// MARK: - For External SDK Clients

/// Always connects to production (regardless of build type)
SwiftlyFeedback.configure(with: "sf_abc123")

// MARK: - For Feedback Kit Internal Apps

/// Auto-detects: DEBUG→localhost, TestFlight→staging, AppStore→production
SwiftlyFeedback.configureWithEnvironmentDetection(with: "sf_abc123")
```

---

## Code Changes

### File: `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/SwiftlyFeedback.swift`

#### Change 1: Update `configure(with:)` to use Production

**Current (lines 99-110):**
```swift
public static func configure(with apiKey: String) {
    configure(with: apiKey, baseURL: URL(string: "http://localhost:8080/api/v1")!)
}
```

**New:**
```swift
/// Configure the SDK with your API key.
///
/// Connects to the Feedback Kit production server. Use this for all external apps.
/// All build types (Xcode, TestFlight, App Store) will connect to production.
///
/// ```swift
/// SwiftlyFeedback.configure(with: "sf_your_api_key")
/// ```
///
/// - Parameter apiKey: Your project's API key from the Feedback Kit dashboard
public static func configure(with apiKey: String) {
    let productionURL = URL(string: "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com/api/v1")!
    configure(with: apiKey, baseURL: productionURL)
}
```

#### Change 2: Rename `configureAuto` to `configureWithEnvironmentDetection`

**Current (lines 70-97):**
```swift
public static func configureAuto(with apiKey: String) {
    let baseURL = detectServerURL()
    configure(with: apiKey, baseURL: baseURL)
    // ... logging
}
```

**New:**
```swift
/// Configure the SDK with automatic server detection based on build environment.
///
/// - Important: For Feedback Kit internal use only. External apps should use `configure(with:)`.
///
/// Server selection:
/// - DEBUG builds → localhost:8080
/// - TestFlight builds → staging server
/// - App Store builds → production server
///
/// - Parameter apiKey: Your project's API key (must exist on the target server)
public static func configureWithEnvironmentDetection(with apiKey: String) {
    let baseURL = detectServerURL()
    configure(with: apiKey, baseURL: baseURL)

    #if DEBUG
    SDKLogger.info("Configured with localhost (DEBUG)")
    #else
    if BuildEnvironment.isTestFlight {
        SDKLogger.info("Configured with staging (TestFlight)")
    } else {
        SDKLogger.info("Configured with production (App Store)")
    }
    #endif
}

@available(*, deprecated, renamed: "configureWithEnvironmentDetection(with:)")
public static func configureAuto(with apiKey: String) {
    configureWithEnvironmentDetection(with: apiKey)
}
```

---

### File: `SwiftlyFeedbackAdmin/...`

Update Admin app to use new method:

```swift
SwiftlyFeedback.configureWithEnvironmentDetection(with: apiKey)
```

---

### File: `SwiftlyFeedbackDemoApp/...`

Update Demo app to use new method:

```swift
SwiftlyFeedback.configureWithEnvironmentDetection(with: apiKey)
```

---

## Summary

| Method | Target User | Behavior |
|--------|-------------|----------|
| `configure(with:)` | External clients | Always Production |
| `configure(with:baseURL:)` | Self-hosted | Custom URL |
| `configureWithEnvironmentDetection(with:)` | Feedback Kit team | Auto-detect environment |
| `configureAuto(with:)` | Deprecated | Alias for above |

---

## Testing Checklist

- [ ] `configure(with:)` connects to production in DEBUG
- [ ] `configure(with:)` connects to production in TestFlight
- [ ] `configure(with:)` connects to production in App Store
- [ ] `configureWithEnvironmentDetection(with:)` uses localhost in DEBUG
- [ ] `configureWithEnvironmentDetection(with:)` uses staging in TestFlight
- [ ] `configureWithEnvironmentDetection(with:)` uses production in App Store
- [ ] Admin app works correctly
- [ ] Demo app works correctly
- [ ] SDK builds without warnings
