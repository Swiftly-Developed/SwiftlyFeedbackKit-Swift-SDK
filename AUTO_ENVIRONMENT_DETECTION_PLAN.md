# Auto-Environment Detection Plan

## Overview
Implement automatic environment detection for both server and client sides to eliminate manual configuration and ensure correct server connections across different deployment contexts.

## Requirements Summary
1. **Server**: Auto-detect environment from `APP_ENV` variable
2. **Admin App**: Auto-select server based on build type (DEBUG→localhost, TestFlight→staging, AppStore→production)
3. **SDK**: Add auto-detect mode for server selection
4. **Emails**: Keep code-based flow, make existing deep links environment-aware

## Architecture Approach

### Server-Side Environment Detection
- Read `APP_ENV` from environment variable (already configured: "development", "staging", "production")
- Store as application state accessible throughout the app
- Use for conditional behavior (email URLs, logging, etc.)

### Client-Side Environment Detection
- Use compile-time flags (`#if DEBUG`, `#if TESTFLIGHT`) for build type detection
- Add runtime TestFlight detection as fallback
- Map build types to server environments automatically

### URL Configuration Strategy
- Server URLs stored as configuration constants
- Environment-specific URL resolution
- No hardcoded Heroku URLs in client apps

---

## Implementation Plan

### Phase 1: Server-Side Environment Detection

#### 1.1 Create AppEnvironment Service
**File**: `SwiftlyFeedbackServer/Sources/App/Services/AppEnvironment.swift`

Create a new service to manage environment detection:

```swift
enum EnvironmentType: String {
    case development
    case staging
    case production
    case local  // For local development

    var name: String { rawValue }
}

final class AppEnvironment {
    static let shared = AppEnvironment()

    let type: EnvironmentType
    let serverURL: String

    private init() {
        // Read APP_ENV from environment
        if let appEnv = Environment.get("APP_ENV") {
            switch appEnv.lowercased() {
            case "development":
                self.type = .development
                self.serverURL = "https://feedbackkit-dev-3d08c4624108.herokuapp.com"
            case "staging":
                self.type = .staging
                self.serverURL = "https://feedbackkit-testflight-2e08ccf13bc4.herokuapp.com"
            case "production":
                self.type = .production
                self.serverURL = "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com"
            default:
                self.type = .local
                self.serverURL = "http://localhost:8080"
            }
        } else {
            // Default to local for development
            self.type = .local
            self.serverURL = "http://localhost:8080"
        }
    }

    var isDevelopment: Bool { type == .development }
    var isStaging: Bool { type == .staging }
    var isProduction: Bool { type == .production }
    var isLocal: Bool { type == .local }
}
```

**Integration Points**:
- Initialize in `configure.swift` and log detected environment
- Use in EmailService for environment-aware deep links
- Use for conditional logging/behavior

#### 1.2 Update configure.swift
**File**: `SwiftlyFeedbackServer/Sources/App/configure.swift`

Add logging after database configuration:

```swift
// Log detected environment
let appEnv = AppEnvironment.shared
app.logger.info("Environment detected: \(appEnv.type.name)")
app.logger.info("Server URL: \(appEnv.serverURL)")
```

#### 1.3 Update EmailService for Environment-Aware Deep Links
**File**: `SwiftlyFeedbackServer/Sources/App/Services/EmailService.swift`

Currently has hardcoded deep link:
```swift
let unsubscribeLink = showUnsubscribe ? """
<a href="feedbackkit://settings/notifications" style="...">
  Manage email preferences
</a>
"""
```

**No changes needed** - `feedbackkit://` scheme is app-specific and doesn't vary by environment. The app handles routing internally.

**However**, if we want to add environment context for future web-based links:

```swift
private func getBaseURL() -> String {
    return AppEnvironment.shared.serverURL
}

// Use in future web links (not needed now):
// let verifyURL = "\(getBaseURL())/verify?code=\(code)"
```

---

### Phase 2: Client-Side Auto-Detection (Admin App)

#### 2.1 Enhance AppEnvironment Detection
**File**: `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Settings/DeveloperCommandsView.swift`

Update the existing `AppEnvironment` enum with runtime TestFlight detection:

```swift
enum AppEnvironment {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var isTestFlight: Bool {
        #if TESTFLIGHT
        return true
        #else
        // Runtime detection fallback
        return isRunningInTestFlight()
        #endif
    }

    static var isAppStore: Bool {
        !isDebug && !isTestFlight
    }

    static var isDeveloperMode: Bool {
        isDebug || isTestFlight
    }

    // Runtime TestFlight detection
    private static func isRunningInTestFlight() -> Bool {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
    }
}
```

#### 2.2 Update ServerEnvironment with Auto-Detection
**File**: `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Services/ServerEnvironment.swift`

Add auto-detection based on build type:

```swift
enum ServerEnvironment: String, CaseIterable, Identifiable {
    case localhost = "localhost"
    case dev = "development"
    case staging = "staging"
    case production = "production"

    var baseURL: URL {
        switch self {
        case .localhost:
            return URL(string: "http://localhost:8080/api/v1")!
        case .dev:
            return URL(string: "https://feedbackkit-dev-3d08c4624108.herokuapp.com/api/v1")!
        case .staging:
            return URL(string: "https://feedbackkit-testflight-2e08ccf13bc4.herokuapp.com/api/v1")!
        case .production:
            return URL(string: "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com/api/v1")!
        }
    }

    // Auto-detect appropriate environment based on build type
    static var autoDetected: ServerEnvironment {
        if AppEnvironment.isDebug {
            return .localhost
        } else if AppEnvironment.isTestFlight {
            return .staging
        } else {
            return .production  // App Store build
        }
    }

    static var current: ServerEnvironment {
        get {
            // Check if user has manually overridden (only in DEBUG/TestFlight)
            if AppEnvironment.isDeveloperMode,
               let rawValue = UserDefaults.standard.string(forKey: "com.swiftlyfeedback.admin.serverEnvironment"),
               let environment = ServerEnvironment(rawValue: rawValue) {
                return environment
            }

            // Otherwise use auto-detected environment
            return autoDetected
        }
        set {
            // Only allow manual override in DEBUG/TestFlight builds
            guard AppEnvironment.isDeveloperMode else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: "com.swiftlyfeedback.admin.serverEnvironment")
        }
    }

    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "com.swiftlyfeedback.admin.serverEnvironment")
    }
}
```

**Key Changes**:
- `autoDetected` property maps build type to environment
- `current` getter prioritizes manual override in developer mode, falls back to auto-detect
- `current` setter only works in developer mode (DEBUG/TestFlight)
- App Store builds always use production (no manual override)

#### 2.3 Update DeveloperCommandsView UI
**File**: `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Settings/DeveloperCommandsView.swift`

Update the Server Environment section (around line 694):

```swift
Section {
    HStack {
        Label("Current Server", systemImage: "server.rack")
        Spacer()
        Text(selectedEnvironment.displayName)
        Circle().fill(colorForEnvironment(selectedEnvironment)).frame(width: 8, height: 8)
    }

    // Show auto-detected environment
    HStack {
        Label("Auto-Detected", systemImage: "wand.and.stars")
        Spacer()
        Text(ServerEnvironment.autoDetected.displayName)
            .foregroundStyle(.secondary)
    }

    // Only show picker in DEBUG/TestFlight
    if AppEnvironment.isDeveloperMode {
        Picker("Override Server", selection: $selectedEnvironment) {
            ForEach(ServerEnvironment.allCases) { env in
                HStack {
                    Text(env.displayName)
                    Circle().fill(colorForEnvironment(env)).frame(width: 8, height: 8)
                }.tag(env)
            }
        }
        .onChange(of: selectedEnvironment) { oldValue, newValue in
            changeEnvironment(to: newValue)
        }

        Button("Reset to Auto-Detected") {
            ServerEnvironment.resetToDefault()
            selectedEnvironment = ServerEnvironment.current
            Task {
                await testConnection()
            }
        }
    } else {
        Text("Using auto-detected environment (production)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    Button { Task { await testConnection() } } label: {
        Label(isTestingConnection ? "Testing..." : "Test Connection", systemImage: "network")
    }
    .disabled(isTestingConnection)

    if let result = connectionTestResult {
        Label(result, systemImage: result.contains("Success") ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(result.contains("Success") ? .green : .red)
            .font(.caption)
    }
} header: {
    Label("Server Environment", systemImage: "server.rack")
} footer: {
    if AppEnvironment.isDeveloperMode {
        Text("In developer mode, you can override the auto-detected server. App Store builds always use production.")
    } else {
        Text("App Store builds automatically connect to the production server.")
    }
}
```

#### 2.4 Update SettingsView
**File**: `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Settings/SettingsView.swift`

Update the build environment indicator (around line 70):

```swift
Section {
    HStack {
        Label("Build Environment", systemImage: "hammer.fill")
        Spacer()
        if AppEnvironment.isDebug {
            Text("Debug")
                .foregroundStyle(.blue)
        } else if AppEnvironment.isTestFlight {
            Text("TestFlight")
                .foregroundStyle(.orange)
        } else {
            Text("App Store")
                .foregroundStyle(.green)
        }
    }

    HStack {
        Label("Server Environment", systemImage: "server.rack")
        Spacer()
        Text(ServerEnvironment.current.displayName)
            .foregroundStyle(.secondary)
    }
} header: {
    Text("Environment")
}
```

---

### Phase 3: SDK Auto-Detection

#### 3.1 Add Auto-Detection to SDK Configuration
**File**: `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/SwiftlyFeedback.swift`

Add new configuration method with auto-detection:

```swift
/// Configure SwiftlyFeedback with automatic server detection based on build type
/// - DEBUG builds → localhost:8080
/// - TestFlight builds → staging server
/// - App Store builds → production server
public static func configureAuto(with apiKey: String) {
    let baseURL = detectServerURL()
    configure(with: apiKey, baseURL: baseURL)

    #if DEBUG
    print("[SwiftlyFeedback] Auto-configured with localhost (DEBUG)")
    #elseif TESTFLIGHT
    print("[SwiftlyFeedback] Auto-configured with staging (TESTFLIGHT)")
    #else
    print("[SwiftlyFeedback] Auto-configured with production (App Store)")
    #endif
}

private static func detectServerURL() -> URL {
    #if DEBUG
    return URL(string: "http://localhost:8080/api/v1")!
    #elseif TESTFLIGHT
    return URL(string: "https://feedbackkit-testflight-2e08ccf13bc4.herokuapp.com/api/v1")!
    #else
    // Production (App Store)
    return URL(string: "https://feedbackkit-production-cbea7fa4b19d.herokuapp.com/api/v1")!
    #endif
}

// Keep existing manual configuration methods
public static func configure(with apiKey: String) {
    configure(with: apiKey, baseURL: URL(string: "http://localhost:8080/api/v1")!)
}

public static func configure(with apiKey: String, baseURL: URL) {
    // ... existing implementation
}
```

#### 3.2 Update Demo App to Use Auto-Detection
**File**: `SwiftlyFeedbackDemoApp/SwiftlyFeedbackDemoApp/SwiftlyFeedbackDemoAppApp.swift`

Replace manual configuration:

```swift
// OLD:
// SwiftlyFeedback.configure(with: "sf_SoCZZ2mWzdUEPPvWUAXgE7iTUjEbs9PJ")

// NEW:
SwiftlyFeedback.configureAuto(with: "sf_SoCZZ2mWzdUEPPvWUAXgE7iTUjEbs9PJ")
```

#### 3.3 Add TESTFLIGHT Build Flag to Xcode
**Required Configuration**:

For the SDK and client apps to properly detect TestFlight builds:

1. Open Xcode project settings
2. Select the target (SwiftlyFeedbackAdmin, SwiftlyFeedbackDemoApp)
3. Go to Build Settings → Swift Compiler - Custom Flags
4. Add to "Active Compilation Conditions":
   - **TestFlight configuration**: Add `TESTFLIGHT`
   - **Debug configuration**: Already has `DEBUG`
   - **Release configuration**: No flags (App Store)

Or add to `.xcconfig` file:
```
SWIFT_ACTIVE_COMPILATION_CONDITIONS[config=TestFlight] = TESTFLIGHT
```

---

## Critical Files to Modify

### Server
1. **SwiftlyFeedbackServer/Sources/App/Services/AppEnvironment.swift** (NEW)
   - Create environment detection service
   - Parse APP_ENV variable
   - Provide serverURL and environment type

2. **SwiftlyFeedbackServer/Sources/App/configure.swift** (MODIFY)
   - Log detected environment on startup
   - Reference AppEnvironment.shared

### Admin App
3. **SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Settings/DeveloperCommandsView.swift** (MODIFY)
   - Enhance AppEnvironment with runtime TestFlight detection
   - Update UI to show auto-detected environment
   - Hide manual override in App Store builds

4. **SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Services/ServerEnvironment.swift** (MODIFY)
   - Add autoDetected computed property
   - Update current getter/setter for auto-detection
   - Add resetToDefault() method

5. **SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Settings/SettingsView.swift** (MODIFY)
   - Add environment indicators
   - Show current build type and server

### SDK
6. **SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/SwiftlyFeedback.swift** (MODIFY)
   - Add configureAuto() method
   - Add detectServerURL() helper
   - Keep existing manual configuration

7. **SwiftlyFeedbackDemoApp/SwiftlyFeedbackDemoApp/SwiftlyFeedbackDemoAppApp.swift** (MODIFY)
   - Switch to configureAuto()

---

## Verification Plan

### Server Verification
```bash
# 1. Check local server
swift run
# Should log: "Environment detected: local"
# Should log: "Server URL: http://localhost:8080"

# 2. Check Heroku dev
heroku logs --tail -a feedbackkit-dev
# Should log: "Environment detected: development"
# Should log: "Server URL: https://feedbackkit-dev-3d08c4624108.herokuapp.com"

# 3. Check Heroku staging
heroku logs --tail -a feedbackkit-testflight
# Should log: "Environment detected: staging"

# 4. Check Heroku production
heroku logs --tail -a feedbackkit-production
# Should log: "Environment detected: production"
```

### Admin App Verification
1. **DEBUG Build (Xcode)**:
   - Run in Xcode
   - Settings → Developer Commands → Server Environment
   - Should show "Auto-Detected: localhost"
   - Should allow manual override with picker
   - Test connection should succeed to localhost

2. **TestFlight Build**:
   - Archive and upload to TestFlight
   - Install from TestFlight
   - Settings → should show "TestFlight" build type
   - Developer Commands → should show "Auto-Detected: staging"
   - Should allow manual override
   - Test connection should succeed to staging server

3. **App Store Build**:
   - Production build (not from TestFlight)
   - Settings → should show "App Store" build type
   - Developer Commands → should show "Using auto-detected environment (production)"
   - NO manual override picker
   - Should automatically connect to production

### SDK Verification
1. **Demo App - DEBUG**:
   - Run in Xcode
   - Should print: "[SwiftlyFeedback] Auto-configured with localhost (DEBUG)"
   - Submit feedback → should go to local server

2. **Demo App - TestFlight**:
   - Build with TestFlight configuration
   - Should print: "[SwiftlyFeedback] Auto-configured with staging (TESTFLIGHT)"
   - Submit feedback → should go to staging server

3. **Demo App - App Store**:
   - Build with Release configuration (no flags)
   - Should print: "[SwiftlyFeedback] Auto-configured with production (App Store)"
   - Submit feedback → should go to production server

---

## Migration Strategy

### For Existing Users (Admin App)
- **First Launch After Update**:
  - Auto-detection kicks in automatically
  - DEBUG users: defaults to localhost (same as before if they had localhost selected)
  - TestFlight users: defaults to staging
  - App Store users: locked to production (can't be changed)

- **If User Had Manual Override**:
  - DEBUG/TestFlight: Manual selection persists, can still override
  - App Store: Manual selection ignored, forced to production

### For SDK Users
- **Breaking Change**: NO
- **configureAuto()**: New method, existing configure() methods still work
- **Recommendation**: Update documentation to encourage configureAuto()

---

## Security Considerations

1. **Server URL Exposure**: URLs are hardcoded in client apps (already the case)
2. **API Keys**: Already handled per-environment (separate keys per project)
3. **App Store Builds**: Can't manually switch to dev/staging (security win)
4. **TestFlight Builds**: Can override for testing purposes (acceptable risk)

---

## Benefits

### For Developers
- ✅ No manual server switching needed
- ✅ Correct environment automatically selected
- ✅ Reduced configuration errors
- ✅ Consistent behavior across deployments

### For End Users (App Store)
- ✅ Always connected to production
- ✅ No accidental connections to dev/staging
- ✅ Better security (can't access test environments)

### For QA/TestFlight Users
- ✅ Auto-connected to staging by default
- ✅ Can still manually test against other environments if needed
- ✅ Clear indication of current environment

---

## Future Enhancements (Out of Scope)

1. **Web-Based Email Links**: Add clickable verification links to emails
2. **Environment-Specific Branding**: Different logos/colors per environment
3. **Feature Flags**: Enable/disable features per environment
4. **Analytics Separation**: Separate analytics per environment
5. **Custom Domain Support**: Replace Heroku URLs with custom domains
