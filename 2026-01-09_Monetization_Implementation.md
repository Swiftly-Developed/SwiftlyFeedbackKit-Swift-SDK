# Monetization Implementation - 2026-01-09

This document records all monetization features implemented based on `TODO_MONETIZATION.md`.

---

## Summary

Implemented **Pro tier** subscription with monthly and yearly billing options, including:
- Server-side feature gating with 402 Payment Required responses
- SDK 402 error handling
- Admin App UI gating with PaywallView integration
- RevenueCat SDK configuration

---

## Completed Tasks

### 1. SDK - 402 Error Handling (SwiftlyFeedbackKit)

#### 1.1 Added Error Case
**File:** `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Networking/SwiftlyFeedbackError.swift`

```swift
case feedbackLimitReached(message: String?)
```

- Added error description returning localized message
- Added Equatable conformance for pattern matching

#### 1.2 Handle 402 in APIClient
**File:** `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Networking/APIClient.swift`

```swift
case 402:
    let errorMessage = parseErrorMessage(from: data)
    SDKLogger.error("Payment required (402): \(errorMessage ?? "Feedback limit reached")")
    throw SwiftlyFeedbackError.feedbackLimitReached(message: errorMessage)
```

#### 1.3 Added Localized Strings
**File:** `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Strings.swift`

```swift
public static var errorFeedbackLimitTitle: LocalizedStringResource
public static var errorFeedbackLimitMessage: LocalizedStringResource
```

**File:** `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Resources/Localizable.xcstrings`

- `error.feedbackLimit.title` = "Feedback Limit Reached"
- `error.feedbackLimit.message` = "This project has reached its feedback limit. Contact the project owner to upgrade."

#### 1.4 Updated Views
**Files:**
- `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Views/SubmitFeedbackView.swift`
- `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Views/FeedbackListView.swift`
- `SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Views/FeedbackDetailView.swift`

Added catch blocks for `feedbackLimitReached` error in all async functions.

---

### 2. Server - Integration Gating (SwiftlyFeedbackServer)

**File:** `SwiftlyFeedbackServer/Sources/App/Controllers/ProjectController.swift`

Added Pro tier requirement to:

| Function | Line | Error Message |
|----------|------|---------------|
| `updateSlackSettings()` | 626-629 | "Slack integration requires Pro subscription" |
| `updateGitHubSettings()` | 719-722 | "GitHub integration requires Pro subscription" |
| `updateClickUpSettings()` | 942-945 | "ClickUp integration requires Pro subscription" |
| `updateNotionSettings()` | 1272-1275 | "Notion integration requires Pro subscription" |
| `updateMondaySettings()` | 1536-1539 | "Monday.com integration requires Pro subscription" |
| `updateLinearSettings()` | 1838-1841 | "Linear integration requires Pro subscription" |
| `addMember()` | 325-328 | "Team members require Pro subscription" |

All checks use:
```swift
guard user.subscriptionTier.meetsRequirement(.pro) else {
    throw Abort(.paymentRequired, reason: "...")
}
```

---

### 3. Admin App - Integration Gating UI (SwiftlyFeedbackAdmin)

**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Projects/ProjectDetailView.swift`

#### 3.1 Added State Variables
```swift
@State private var showingPaywall = false
@State private var subscriptionService = SubscriptionService.shared
```

#### 3.2 Wrapped Integration Menu Items
Replaced `Button` with `SubscriptionGatedButton` for:
- Slack
- GitHub
- ClickUp
- Notion
- Monday.com
- Linear

Each button includes `.tierBadge(.pro)` modifier to show "Pro" badge for Free users.

#### 3.3 Wrapped Manage Members Button
Both menu button and QuickActionButton now check Pro tier before showing members sheet.

#### 3.4 Added Paywall Sheet
```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView()
}
```

---

### 4. Admin App - Feedback Count Indicator

**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Feedback/FeedbackDashboardView.swift`

Added toolbar item showing "X/10" feedback count for Free tier users:

```swift
if subscriptionService.currentTier == .free,
   let maxFeedback = subscriptionService.currentTier.maxFeedbackPerProject {
    ToolbarItem(placement: .automatic) {
        Text("\(feedbackViewModel.allFeedback.count)/\(maxFeedback)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(...)
    }
}
```

---

### 5. Configuration Updates

**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Services/SubscriptionService.swift`

#### 5.1 RevenueCat API Key
```swift
static let revenueCatAPIKey = "appl_qwlqUlehsPfFfhvmaWLAqfEKMGs"
```

#### 5.2 Product IDs
```swift
enum ProductID: String, CaseIterable {
    case proMonthly = "swiftlyfeedback.pro.monthly"
    case proYearly = "swiftlyfeedback.pro.yearly"
    case teamMonthly = "swiftlyfeedback.team.monthly"
    case teamYearly = "swiftlyfeedback.team.yearly"
}
```

#### 5.3 Entitlement ID
```swift
static let proEntitlementID = "Swiftly Pro"
```

---

### 6. Bug Fixes During Implementation

#### 6.1 Database Error
- **Issue:** `database "swiftly_feedback" does not exist`
- **Fix:** Created database with `createdb -U postgres swiftly_feedback`

#### 6.2 Server Compilation Errors
- **Issue:** `cannot find type 'Database' in scope` in RevenueCatService.swift
- **Fix:** Added `import Fluent`

- **Issue:** `cannot infer contextual base in reference to member 'active'`
- **Fix:** Used explicit enum types (`SubscriptionStatus.active`, `SubscriptionTier.pro`)

#### 6.3 Admin App Compilation Errors
- **Issue:** `Reference to member 'secondarySystemBackground' cannot be resolved`
- **Fix:** Added platform-specific conditionals for iOS/macOS colors in PaywallView.swift and ProjectListView.swift

#### 6.4 Bundle ID Change
- **Changed:** `com.swiftly-developed.SwiftlyFeedbackAdmin` → `com.swiftly-developed.SwiftlyFeedbackKit`

---

## RevenueCat Dashboard Configuration

### Products
| Product ID | Description |
|------------|-------------|
| `swiftlyfeedback.pro.monthly` | Pro Monthly ($15/month) |
| `swiftlyfeedback.pro.yearly` | Pro Yearly ($150/year) |
| `swiftlyfeedback.team.monthly` | Team Monthly ($39/month) |
| `swiftlyfeedback.team.yearly` | Team Yearly ($390/year) |

### Entitlements
| Identifier | Products |
|------------|----------|
| `Swiftly Pro` | All 4 products (Pro + Team) |
| `Swiftly Team` | Team products only |

### Offerings
| Offering | Packages |
|----------|----------|
| `default` | `$rc_monthly`, `$rc_annual`, `team_monthly`, `team_annual` |

---

## Files Modified

### SwiftlyFeedbackKit (SDK)
- `Sources/SwiftlyFeedbackKit/Networking/SwiftlyFeedbackError.swift`
- `Sources/SwiftlyFeedbackKit/Networking/APIClient.swift`
- `Sources/SwiftlyFeedbackKit/Strings.swift`
- `Sources/SwiftlyFeedbackKit/Resources/Localizable.xcstrings`
- `Sources/SwiftlyFeedbackKit/Views/SubmitFeedbackView.swift`
- `Sources/SwiftlyFeedbackKit/Views/FeedbackListView.swift`
- `Sources/SwiftlyFeedbackKit/Views/FeedbackDetailView.swift`

### SwiftlyFeedbackServer
- `Sources/App/Controllers/ProjectController.swift`
- `Sources/App/Services/RevenueCatService.swift` (added `import Fluent`)

### SwiftlyFeedbackAdmin
- `SwiftlyFeedbackAdmin/Views/Projects/ProjectDetailView.swift`
- `SwiftlyFeedbackAdmin/Views/Feedback/FeedbackDashboardView.swift`
- `SwiftlyFeedbackAdmin/Views/Settings/PaywallView.swift`
- `SwiftlyFeedbackAdmin/Views/Projects/ProjectListView.swift`
- `SwiftlyFeedbackAdmin/Services/SubscriptionService.swift`
- `SwiftlyFeedbackAdmin.xcodeproj/project.pbxproj` (bundle ID change)

---

## Remaining Tasks

### Server Environment Variables
```bash
REVENUECAT_API_KEY=sk_xxxxxxxxxxxx
REVENUECAT_WEBHOOK_SECRET=whsec_xxxxxxxx
```

### RevenueCat Webhook
- URL: `https://your-api.com/api/v1/webhooks/revenuecat`
- Enable all subscription events

### Team Tier Entitlement
- Add `Swiftly Team` entitlement check to SubscriptionService.swift (if implementing Team tier detection)

---

## Testing Checklist

### Server
- [ ] Free user cannot create 2nd project → 402
- [ ] Pro user can create 2 projects
- [ ] Free project rejects 11th feedback → 402
- [ ] Free user cannot enable Slack → 402
- [ ] Free user cannot invite members → 402
- [ ] Pro user can enable integrations and invite members

### Admin App
- [ ] Free tier user sees "1/1 Projects" indicator
- [ ] Free tier user sees PaywallView when trying to add integration
- [ ] Free tier user sees "Pro" badge on gated features
- [ ] Feedback count shows "X/10" for Free tier
- [ ] Purchase flow completes successfully
- [ ] Restore purchases works

### SDK
- [ ] Submit feedback on project at limit → see "Feedback Limit Reached" error
- [ ] Error message is user-friendly
