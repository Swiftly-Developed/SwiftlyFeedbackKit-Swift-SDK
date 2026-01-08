# CLAUDE.md - SwiftlyFeedbackAdmin

Admin application for managing feedback projects, members, and viewing feedback.

## Build & Test

```bash
# Build via workspace
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin -sdk iphonesimulator -configuration Debug

# Test
xcodebuild -workspace ../Swiftlyfeedback.xcworkspace -scheme SwiftlyFeedbackAdmin test -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Directory Structure

```
SwiftlyFeedbackAdmin/
├── SwiftlyFeedbackAdminApp.swift   # App entry point
├── Models/
│   ├── AuthModels.swift            # User, token models
│   ├── ProjectModels.swift         # Project, member models
│   ├── FeedbackModels.swift        # Feedback, Comment models, DTOs
│   ├── SDKUserModels.swift         # SDK user and stats models
│   ├── ViewEventModels.swift       # View event and stats models
│   └── HomeDashboardModels.swift   # Home dashboard KPI models
├── ViewModels/
│   ├── AuthViewModel.swift         # Authentication state
│   ├── ProjectViewModel.swift      # Project management state
│   ├── FeedbackViewModel.swift     # Feedback management state
│   ├── SDKUserViewModel.swift      # SDK user management state
│   ├── ViewEventViewModel.swift    # View event management state
│   ├── HomeDashboardViewModel.swift # Home dashboard state
│   └── OnboardingViewModel.swift   # Onboarding state + OnboardingManager
├── Views/
│   ├── RootView.swift              # Root navigation
│   ├── MainTabView.swift           # Tab bar navigation
│   ├── Home/
│   │   └── HomeDashboardView.swift   # Home dashboard with KPIs
│   ├── Auth/
│   │   ├── AuthContainerView.swift    # Auth flow container
│   │   ├── LoginView.swift            # Login form
│   │   ├── SignupView.swift           # Signup form
│   │   ├── EmailVerificationView.swift # Email verification screen
│   │   └── ForgotPasswordView.swift   # Password reset flow
│   ├── Onboarding/
│   │   ├── OnboardingContainerView.swift    # Onboarding flow container
│   │   ├── OnboardingWelcomeView.swift      # Welcome screen
│   │   ├── OnboardingCreateAccountView.swift # Account creation
│   │   ├── OnboardingVerifyEmailView.swift  # Email verification
│   │   ├── OnboardingProjectChoiceView.swift # Create/join choice
│   │   ├── OnboardingCreateProjectView.swift # Project creation
│   │   ├── OnboardingJoinProjectView.swift  # Join via invite
│   │   └── OnboardingCompletionView.swift   # Success screen
│   ├── Projects/
│   │   ├── ProjectListView.swift      # Project list with 3 view modes (list/table/grid)
│   │   ├── ProjectDetailView.swift    # Project details & feedback
│   │   ├── CreateProjectView.swift    # Create new project sheet
│   │   ├── ProjectMembersView.swift   # Manage members
│   │   ├── AcceptInviteView.swift     # Accept project invite
│   │   ├── SlackSettingsView.swift    # Configure Slack webhook notifications
│   │   ├── GitHubSettingsView.swift   # Configure GitHub Issues integration
│   │   ├── ClickUpSettingsView.swift  # Configure ClickUp Tasks integration
│   │   ├── NotionSettingsView.swift   # Configure Notion database integration
│   │   ├── MondaySettingsView.swift   # Configure Monday.com integration
│   │   └── LinearSettingsView.swift   # Configure Linear integration
│   ├── Feedback/
│   │   ├── FeedbackDashboardView.swift # Dashboard with List/Kanban views
│   │   ├── FeedbackListView.swift      # Feedback list with row view
│   │   └── FeedbackDetailView.swift    # Feedback detail with comments
│   ├── Users/
│   │   ├── UsersDashboardView.swift    # Users dashboard with stats and list
│   │   └── UsersListView.swift         # Users list (legacy, used in project detail)
│   ├── Events/
│   │   └── EventsDashboardView.swift   # Events dashboard with chart and stats
│   └── Settings/
│       ├── SettingsView.swift          # App settings
│       └── DeveloperCommandsView.swift # Dev tools (DEBUG/TestFlight only)
└── Services/
    ├── AdminAPIClient.swift        # API client for admin endpoints
    ├── AuthService.swift           # Authentication logic
    ├── KeychainService.swift       # Secure token storage
    └── Logger.swift                # Centralized OSLog logging categories
```

## Onboarding Flow

New users are guided through a multi-step onboarding process before accessing the main app:

### Steps
1. **Welcome** (`OnboardingWelcomeView`) - App introduction with feature highlights
2. **Create Account** (`OnboardingCreateAccountView`) - Name, email, password form
3. **Verify Email** (`OnboardingVerifyEmailView`) - 8-character verification code
4. **Project Choice** (`OnboardingProjectChoiceView`) - Create new or join existing project
5. **Create/Join Project** (`OnboardingCreateProjectView` / `OnboardingJoinProjectView`)
6. **Completion** (`OnboardingCompletionView`) - Success screen with next steps

### Files
```
Views/Onboarding/
├── OnboardingContainerView.swift      # Main container managing step transitions
├── OnboardingWelcomeView.swift        # Welcome screen with FeedbackKit logo
├── OnboardingCreateAccountView.swift  # Account creation form
├── OnboardingVerifyEmailView.swift    # Email verification code entry
├── OnboardingProjectChoiceView.swift  # Create or join project choice
├── OnboardingCreateProjectView.swift  # New project form
├── OnboardingJoinProjectView.swift    # Join via invite code
└── OnboardingCompletionView.swift     # Success and next steps

ViewModels/
└── OnboardingViewModel.swift          # Onboarding state + OnboardingManager
```

### OnboardingManager
Singleton managing onboarding completion state via `UserDefaults`:
- `hasCompletedOnboarding` - Tracked stored property for SwiftUI observation
- `completeOnboarding()` - Marks onboarding as complete
- `resetOnboarding()` - Resets for testing (available in Developer Commands)

**Important**: Uses a stored property (not computed) so `@Observable` can track changes.

### Platform-Adaptive Design (Apple HIG)
All onboarding views follow Apple Human Interface Guidelines:
- **44pt minimum touch targets** for all interactive elements
- **Platform-specific layouts**: Grid for iPad/Mac, list for iPhone
- **`@Environment(\.horizontalSizeClass)`** for responsive sizing
- **`GeometryReader`** for dynamic spacing based on screen size
- **`#if os(macOS)` / `#else`** for platform-specific code
- **Accessibility**: Labels, hints, and traits on all interactive elements

### RootView Integration
`RootView.swift` manages navigation based on auth and onboarding state:
- Not authenticated + not onboarded → `OnboardingContainerView`
- Not authenticated + onboarded → `AuthContainerView` (login)
- Authenticated + needs verification → `EmailVerificationView`
- Authenticated + not onboarded → `OnboardingPostAuthView`
- Authenticated + onboarded → `MainTabView`

## Authentication Flow

1. User logs in via `LoginView` or signs up via `SignupView`
2. New users must verify email via `EmailVerificationView` (8-character code)
3. Token stored securely in Keychain via `KeychainService`
4. `AuthViewModel` manages authentication state including `needsEmailVerification`
5. `AdminAPIClient` includes Bearer token in requests

### Password Reset Flow

1. User taps "Forgot Password?" on `LoginView`
2. `ForgotPasswordView` shows email entry form
3. Server sends reset code email (8-char code, 1-hour expiry)
4. View transitions to code + new password entry
5. On success, user is returned to login screen to log in with new password

**AuthViewModel Properties:**
- `resetEmail` - Email address for reset
- `resetCode` - 8-character reset code
- `resetNewPassword` / `resetConfirmPassword` - New password fields
- `resetEmailSent` - Whether code has been sent

**AuthViewModel Methods:**
- `requestPasswordReset()` - Send reset code email
- `resetPassword()` - Validate code and set new password
- `clearResetState()` - Reset all password reset fields

### FocusState Navigation

All auth forms use `@FocusState` for keyboard navigation:
- **LoginView**: Email → Password → Submit
- **SignupView**: Name → Email → Password → Confirm → Submit
- **ForgotPasswordView**: Email → Submit OR Code → New Password → Confirm → Submit
- **EmailVerificationView**: Auto-focus code field

## Code Patterns

### ViewModels
- Use `@Observable` classes marked with `@MainActor`
- Follow AGENTS.md guidelines

### Services
- `AdminAPIClient` handles all HTTP requests
- Uses async/await for networking
- Bearer token authentication

### Views
- Follow AGENTS.md SwiftUI guidelines
- Use `NavigationStack` for navigation
- Extract subviews into separate `View` structs
- Use `#if os(iOS)` / `#if os(macOS)` for platform-specific code

## Project List View Modes

The `ProjectListView` supports three view modes (persisted via `@AppStorage`):

| Mode | Icon | Description |
|------|------|-------------|
| List | `list.bullet` | Compact rows with project icon, name, description |
| Table | `tablecells` | Detailed rows with columns (name, feedback count, role, date) |
| Grid | `square.grid.2x2` | Card-based layout with full project info |

## Project Icons

`ProjectIconView` displays project icons with gradient colors:
- Uses `colorIndex` (0-7) from the project to select a gradient pair
- Shows initials (first 2 letters, or first letter of each word for multi-word names)
- Archived projects always show gray gradient with archive icon
- Color picker available in `EditProjectView` for users to customize

## Integrations Visibility

The `ProjectDetailView` displays configured integrations in a dedicated card:

### Features
- Only shown when at least one integration is configured
- Each integration row shows: icon, name, and configuration details
- Tapping a row opens the integration settings sheet

### Integration Details Displayed
| Integration | Icon | Detail Shown (Active) | Detail Shown (Paused) |
|-------------|------|----------------------|----------------------|
| Slack | `number` (teal) | "Notifications enabled" | "Paused" (orange) |
| GitHub | `arrow.triangle.branch` (black) | "owner/repo" | "Paused" (orange) |
| ClickUp | `checklist` (purple) | List name or "Connected" | "Paused" (orange) |
| Notion | `doc.text` (black) | Database name or "Connected" | "Paused" (orange) |
| Monday.com | `calendar` (red) | Board name or "Connected" | "Paused" (orange) |
| Linear | `arrow.triangle.branch` (purple) | Team name or "Connected" | "Paused" (orange) |

### Integration Active Toggle
Each integration has an "Integration Active" toggle that can be enabled/disabled:
- When **active**: Shows normal colored icon and detail text
- When **paused**: Shows gray icon and orange "Paused" text
- Pausing an integration temporarily disables it without removing the configuration

### Configuration Check Properties (ProjectModels.swift)
- `isSlackConfigured` - true if `slackWebhookUrl` is set and non-empty
- `isGitHubConfigured` - true if owner, repo, and token are all set
- `isClickUpConfigured` - true if token and listId are both set
- `isNotionConfigured` - true if token and databaseId are both set
- `isMondayConfigured` - true if token and boardId are both set
- `isLinearConfigured` - true if token and teamId are both set
- `hasAnyIntegration` - true if any of the above are configured

## Cross-Platform Considerations

- Use `Color(.systemBackground)` on iOS, `Color(nsColor: .textBackgroundColor)` on macOS
- Use `#if os(iOS)` for iOS-only modifiers like `.textInputAutocapitalization`
- Use `.presentationDetents` on iOS for sheet sizing
- Use `.frame(minWidth:minHeight:)` on macOS for window sizing
- For `ScrollView` backgrounds that need to extend under navigation bars, use `.ignoresSafeArea()` on iOS

## macOS Navigation

The macOS app uses `NavigationSplitView` with a sidebar (`MainTabView.swift`):

- Sidebar has `.navigationTitle("SwiftlyFeedback")` for proper top area rendering
- Each detail section has its own `NavigationStack` for consistent title styling
- Detail views provide their own `.navigationTitle()` (e.g., "Projects", "Feedback", "Settings")
- Sidebar is split into two sections with a Spacer and Divider:
  - **Top section**: Home, Projects, Feedback, Users, Events
  - **Bottom section**: Feature Requests, Settings

## Feature Requests Tab

The Admin app integrates SwiftlyFeedbackKit to collect feedback from its own users ("eating your own dog food").

### Configuration

In `SwiftlyFeedbackAdminApp.swift`:
```swift
import SwiftlyFeedbackKit

init() {
    // Configure SwiftlyFeedbackKit SDK for in-app feature requests
    SwiftlyFeedback.configure(with: "sf_your_api_key")
    SwiftlyFeedback.theme.primaryColor = .color(.blue)
}
```

### Navigation Placement
- **macOS**: Bottom of sidebar after Divider, before Settings
- **iOS/iPadOS**: Tab with lightbulb icon, uses `.tabViewStyle(.sidebarAdaptable)` for iPad optimization

### Implementation
- Uses `SwiftlyFeedbackKit.FeedbackListView()` directly (no custom wrapper needed)
- SDK is configured once at app launch with a hardcoded API key
- Users can submit feature requests, vote, and view existing feedback

## Shared Project Filter

The Feedback, Users, and Events tabs share a common project filter stored in `ProjectViewModel.selectedFilterProject`. This ensures the selected project persists when switching between tabs.

### Implementation
- `ProjectViewModel.selectedFilterProject: ProjectListItem?` - Shared state for project selection
- Each view uses a computed property to read/write this shared state:
  ```swift
  private var selectedProject: ProjectListItem? {
      get { projectViewModel.selectedFilterProject }
      nonmutating set { projectViewModel.selectedFilterProject = newValue }
  }
  ```
- Views use `.task(id: selectedProject?.id)` to reload data when the project changes or the view appears

### Behavior
- **Feedback tab**: Requires a project selection (auto-selects first project if none selected)
- **Users tab**: Supports "All Projects" option (nil = all projects, default)
- **Events tab**: Supports "All Projects" option (nil = all projects, default)

## Feedback Dashboard

The `FeedbackDashboardView` provides a dedicated tab for managing feedback across all projects:

### View Modes (persisted via `@AppStorage`)

| Mode | Icon | Description |
|------|------|-------------|
| List | `list.bullet` | Traditional list with swipe actions and context menus |
| Kanban | `rectangle.3.group` | Drag-and-drop columns by status (Pending, Approved, In Progress, Completed, Rejected) |

### Features
- Shared project picker in toolbar (persists across tabs)
- Search feedback by title, description, or user email
- Filter by status and/or category
- Update status via context menu, swipe actions, or drag-and-drop (Kanban)
- View feedback details and manage comments

### Kanban Card Layout
Kanban cards display a compact layout to reduce visual clutter:
- **Top row**: Category badge, MRR badge, (merge badge if applicable), Spacer, Integration icons, Vote count
- **Integration icons**: Compact 18x18 circular icons instead of full pill badges with text
- **Title**: 2-line limit
- **Description**: 2-line limit, secondary color
- **Bottom row**: User email (if available), Comment count

### Integration Badge Components
Badge components support both full and compact modes via `compact: Bool` parameter:

| Badge | Icon | Color | Compact Size |
|-------|------|-------|--------------|
| `GitHubBadge` | `arrow.triangle.branch` | primary (gray) | 18x18 circle |
| `ClickUpBadge` | `checklist` | purple | 18x18 circle |
| `NotionBadge` | `doc.text` | primary (gray) | 18x18 circle |
| `MondayBadge` | `calendar` | red | 18x18 circle |
| `LinearBadge` | `lineweight` | indigo | 18x18 circle |

- `IntegrationIconBadge` - Base component for compact circular icon badges
- `IntegrationsRow` - Groups all integration icons horizontally with 4px spacing

## Users Dashboard

The `UsersDashboardView` provides a dedicated tab for viewing SDK users (end users of apps using SwiftlyFeedbackKit):

### Features
- Shared project picker in toolbar (persists across tabs)
- **All Projects** option to view users across all projects (default)
- Stats cards showing: Total Users, Total MRR, Paying Users, Average MRR
- Search users by user ID
- Sort by: Last Seen, MRR, Feedback Count, Vote Count
- User list showing user type (iCloud/Device/Custom), activity stats, and MRR

### User Types
- **iCloud**: Users identified via iCloud (`icloud_` prefix)
- **Device**: Local device-based users (`local_` prefix)
- **Custom**: Custom user identifiers provided by the app

### Logging
Uses `Logger.swift` for centralized OSLog logging via `AppLogger` enum with configurable categories:

```swift
// Disable all Admin app logging
AppLogger.isEnabled = false

// Use category-specific loggers
AppLogger.api.info("Loading projects...")
AppLogger.auth.error("Login failed")
AppLogger.viewModel.debug("State changed")
AppLogger.view.info("View appeared")
AppLogger.data.debug("Parsing response")
AppLogger.keychain.info("Token saved")
```

**Categories:**
- `AppLogger.api` - API requests/responses
- `AppLogger.auth` - Authentication events
- `AppLogger.viewModel` - ViewModel state changes
- `AppLogger.view` - View lifecycle events
- `AppLogger.data` - Model parsing, transformations
- `AppLogger.keychain` - Secure storage operations

**Logging Control:**
- `AppLogger.isEnabled` - Global flag to enable/disable all logging (default: `true`)

**Swift 6 Concurrency:**
The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, meaning all types default to `@MainActor`. The `AppLogger` and `LoggerWrapper` are explicitly marked `nonisolated` to opt out, allowing them to be called from any actor (including `AdminAPIClient` which is an actor).

Key patterns:
- `nonisolated enum AppLogger` - Opts out of MainActor default
- `nonisolated struct LoggerWrapper: @unchecked Sendable` - Thread-safe wrapper
- `nonisolated(unsafe) private var _loggingEnabled` - Simple flag where races have no safety impact

## Developer Commands (DEBUG/TestFlight only)

`DeveloperCommandsView` is available in Settings when running in DEBUG or TestFlight builds:

- **Generate Dummy Projects**: Create test projects with random names
- **Generate Dummy Feedback**: Add test feedback items to a project
- **Generate Dummy Comments**: Add test comments to existing feedback
- **Reset Onboarding**: Reset onboarding state (sign out required to see welcome screen)
- **Clear All Feedback**: Delete all feedback for a project
- **Delete All My Projects**: Remove all projects owned by the user

Controlled by `AppEnvironment.isDeveloperMode` which checks for DEBUG builds or TestFlight sandbox receipt.

## Home Dashboard (KPIs)

The `HomeDashboardView` is the first tab displaying key performance indicators across all projects:

### Features
- **Global KPIs**: Projects count, total feedback, users, comments, and votes
- **Feedback by Status**: Breakdown showing Pending, Approved, In Progress, Completed, Rejected counts
- **Project List**: All projects with their individual feedback/user/comment/vote counts
- **Project Filter**: Toolbar picker to view stats for all projects or a specific project
- Mini status badges (P/IP/C) showing quick feedback status overview per project

### Server Endpoint
- `GET /dashboard/home` - Aggregated statistics across all user's projects (Bearer auth)

## Events Dashboard

The `EventsDashboardView` provides a dedicated tab for viewing SDK view events (screen views and custom events tracked by apps using SwiftlyFeedbackKit):

### Features
- Shared project picker in toolbar (persists across tabs)
- **All Projects** option to view events across all projects (default)
- Stats cards showing: Total Events, Unique Users
- **Daily Events Chart** (Swift Charts) showing event history for selected time period
- **Time Period Filter**: Presets (7d, 30d, 90d, 1y) and custom periods
- Event breakdown showing count and unique users per event type
- Recent events list with user type indicators (iCloud/Device/Custom)

### Time Period Filter
The Events tab includes a flexible time period filter in the toolbar:

**Presets:**
- Last 7 Days (week)
- Last 30 Days (month, default)
- Last 90 Days (quarter)
- Last Year (365 days)

**Custom Period:**
- Select "Custom..." from the menu to open a sheet/popover
- Enter a numeric value and select a unit (Days, Weeks, Months, Years)
- Maximum: 365 days total

**Platform-Specific UI (Apple HIG compliant):**
- **iOS/iPadOS**: Half-sheet with quick select list, stepper for value, menu picker for unit
- **macOS**: Fixed-size popover with horizontal button presets, text field for value, dropdown for unit, keyboard shortcut (Enter to apply)

**Implementation:**
- `TimePeriod` enum with `.week`, `.month`, `.quarter`, `.year`, and `.custom(value:unit:)` cases
- `TimePeriodUnit` enum for Days, Weeks, Months, Years with `toDays()` conversion
- Uses `.task(id:)` modifier to reload data when time period changes
- Server endpoint: `GET /events/all/stats?days=N` or `GET /events/project/:id/stats?days=N`

### Event Types
Events can be any custom string, plus predefined types:
- `feedback_list` - User viewed the feedback list
- `feedback_detail` - User viewed a feedback detail
- `submit_feedback` - User viewed the submit feedback form
- Custom events - Any string defined by the app developer

## Status Settings

Projects can customize which feedback statuses are available. Configure in Project Details > Menu (⋯) > Status Settings.

### StatusSettingsView Features
- Toggle optional statuses on/off (pending is always required)
- Available statuses: Pending, Approved, In Progress, TestFlight, Completed, Rejected
- Reset to default option
- Saves to `allowed_statuses` array on project

### FeedbackStatus Enum
| Status | Raw Value | Color | Can Vote |
|--------|-----------|-------|----------|
| Pending | `pending` | gray | Yes |
| Approved | `approved` | blue | Yes |
| In Progress | `in_progress` | orange | Yes |
| TestFlight | `testflight` | cyan | Yes |
| Completed | `completed` | green | No |
| Rejected | `rejected` | red | No |

## Slack Integration

Projects can send notifications to Slack via Incoming Webhooks. Configure in Project Details > Menu (⋯) > Slack Integration.

### SlackSettingsView Features
- Multiline TextEditor for webhook URL (monospaced font for readability)
- Toggles for notification types: new feedback, comments, status changes
- URL validation (must start with `https://hooks.slack.com/`)
- Remove integration button to clear webhook

### Notification Types
- **New feedback submitted**: When SDK users submit feedback
- **New comments**: When comments are added to feedback
- **Status changes**: When feedback status is updated

## Feedback Merging

Merge duplicate feedback items to consolidate similar requests and get accurate demand signals.

### How to Merge
1. In `FeedbackDashboardView` or `FeedbackListView`, single-click to select feedback items (macOS)
2. Select 2+ items to enable the merge action bar at the bottom
3. Click "Merge Selected" to open the merge sheet
4. Choose which feedback becomes the primary (survives the merge)
5. Confirm to merge votes, comments, and MRR

### UI Components
- **Selection mode**: Single-click selects, double-click opens (macOS); tap opens (iOS)
- **Selection action bar**: Floating bar shows when 2+ items selected with "Merge Selected" button
- **MergeFeedbackSheet**: Sheet to select primary feedback and confirm merge
- **Merge badge**: Purple badge on feedback cards showing count of merged items
- **Context menu**: Right-click options include "Select for Merge" and "Merge X Items..."

### Files
- `MergeFeedbackSheet.swift` - Sheet for selecting primary feedback
- `FeedbackDashboardView.swift` - Main feedback tab with merge support
- `FeedbackListView.swift` - Project detail feedback list with merge support
- `FeedbackViewModel.swift` - Merge logic and selection state management

## GitHub Integration

Push feedback items to GitHub as issues for tracking in your development workflow.

### Setup
1. In your GitHub account, create a Personal Access Token (PAT) with `repo` scope
2. In Admin app: Project Details > Menu (⋯) > GitHub Integration
3. Enter repository owner, name, and token
4. Optionally configure default labels and status sync

### GitHubSettingsView Features
- Repository owner and name fields
- SecureField for Personal Access Token
- Default labels (comma-separated) applied to all issues
- Status sync toggle: auto-close issues when feedback completed/rejected
- Help button linking to GitHub token creation page
- Remove integration button

### Feedback Context Menu Actions
- **Push to GitHub**: Create a GitHub issue from feedback (only shown if GitHub configured and no existing issue)
- **View GitHub Issue**: Open the linked issue in browser (only shown if feedback has an issue)

### Bulk Actions
When selecting multiple feedback items, the action bar includes "Push to GitHub" button to create issues for all selected items that don't already have GitHub issues.

### Visual Indicators
- GitHub badge (branch icon) on feedback cards that have linked issues
- Success toast showing issue number when created

### Files
- `GitHubSettingsView.swift` - Settings sheet for GitHub integration
- `FeedbackDashboardView.swift` - Context menu with Push/View GitHub actions
- `FeedbackListView.swift` - Row context menu with GitHub actions
- `FeedbackViewModel.swift` - `createGitHubIssue()` and `bulkCreateGitHubIssues()` methods
- `AdminAPIClient.swift` - `createGitHubIssue()` and `bulkCreateGitHubIssues()` API calls

## ClickUp Integration

Push feedback items to ClickUp as tasks for tracking in your project management workflow.

### Setup
1. Get your ClickUp API token from Settings > Apps in ClickUp
2. In Admin app: Project Details > Menu (⋯) > Integrations > ClickUp
3. Enter your API token and select the target list via the hierarchy picker
4. Optionally configure default tags, status sync, comment sync, and vote count sync

### ClickUpSettingsView Features
- API token SecureField
- Hierarchy picker: Workspace → Space → Folder (optional) → List
- Default tags (comma-separated) applied to all tasks
- Status sync toggle: auto-update ClickUp task status when feedback status changes
- Comment sync toggle: sync comments to ClickUp tasks
- Vote count field picker: select a number custom field to sync vote counts
- Remove integration button

### Status Mapping
When status sync is enabled:
- **pending** → "to do"
- **approved** → "approved"
- **in_progress** → "in progress"
- **testflight** → "in review"
- **completed** → "complete"
- **rejected** → "closed"

### Feedback Context Menu Actions
- **Push to ClickUp**: Create a ClickUp task from feedback (only shown if ClickUp configured and no existing task)
- **View ClickUp Task**: Open the linked task in browser (only shown if feedback has a task)

### Bulk Actions
When selecting multiple feedback items, the action bar includes "Push to ClickUp" button to create tasks for all selected items that don't already have ClickUp tasks.

### Visual Indicators
- Purple ClickUp badge on feedback cards that have linked tasks
- Success toast showing task URL when created

### Files
- `ClickUpSettingsView.swift` - Settings sheet for ClickUp integration with hierarchy picker
- `FeedbackDashboardView.swift` - Context menu with Push/View ClickUp actions
- `FeedbackListView.swift` - Row context menu with ClickUp actions, ClickUpBadge component
- `FeedbackViewModel.swift` - `createClickUpTask()` and `bulkCreateClickUpTasks()` methods
- `ProjectViewModel.swift` - `updateClickUpSettings()` and hierarchy loading methods
- `AdminAPIClient.swift` - All ClickUp API calls (settings, tasks, hierarchy)
- `ProjectModels.swift` - ClickUp request/response DTOs and hierarchy models

## Notion Integration

Push feedback items to Notion as database pages for tracking in your knowledge management workflow.

### Setup
1. Create a Notion Internal Integration at https://www.notion.so/my-integrations
2. Copy the "Internal Integration Secret" (starts with `secret_`)
3. Share your target database with the integration (database page → ⋯ → Add connections)
4. In Admin app: Project Details > Menu (⋯) > Integrations > Notion
5. Enter your token and select the target database via the picker
6. Optionally configure status sync, comment sync, and vote count property

### NotionSettingsView Features
- Integration token SecureField
- Database picker: dynamically loads databases shared with integration
- Status property picker: select Status-type property for status sync
- Votes property picker: select Number-type property for vote count sync
- Status sync toggle: auto-update Notion page status when feedback status changes
- Comment sync toggle: sync comments to Notion pages
- Remove integration button

### Status Mapping
When status sync is enabled:
- **pending** → "To Do"
- **approved** → "Approved"
- **in_progress** → "In Progress"
- **testflight** → "In Review"
- **completed** → "Complete"
- **rejected** → "Closed"

### Feedback Context Menu Actions
- **Push to Notion**: Create a Notion page from feedback (only shown if Notion configured and no existing page)
- **View Notion Page**: Open the linked page in browser (only shown if feedback has a page)

### Bulk Actions
When selecting multiple feedback items, the action bar includes "Push to Notion" button to create pages for all selected items that don't already have Notion pages.

### Visual Indicators
- Black Notion badge on feedback cards that have linked pages
- Success toast showing page creation when created

### Files
- `NotionSettingsView.swift` - Settings sheet for Notion integration with database picker
- `FeedbackDashboardView.swift` - Context menu with Push/View Notion actions
- `FeedbackListView.swift` - Row context menu with Notion actions, NotionBadge component
- `FeedbackViewModel.swift` - `createNotionPage()` and `bulkCreateNotionPages()` methods
- `ProjectViewModel.swift` - `updateNotionSettings()`, `loadNotionDatabases()`, `loadNotionDatabaseProperties()` methods
- `AdminAPIClient.swift` - All Notion API calls (settings, pages, databases)
- `ProjectModels.swift` - Notion request/response DTOs

## Subscription Integration (Stub)

The Admin app has subscription infrastructure in place, but RevenueCat is **not yet integrated**. The `SubscriptionService` currently returns `.free` tier for all users.

### Current Status

- **RevenueCat SDK**: Not integrated (removed to fix build issues)
- **All users**: Free tier by default
- **Subscriptions UI**: Shows "Coming Soon" message

### SubscriptionService

`SubscriptionService.swift` is a stub that will integrate with RevenueCat in the future:

```swift
// Access singleton
let service = SubscriptionService.shared

// Configure at app launch (done in SwiftlyFeedbackAdminApp.swift)
SubscriptionService.shared.configure()  // No-op currently

// Login/logout (called from AuthViewModel)
await SubscriptionService.shared.login(userId: user.id)   // No-op currently
await SubscriptionService.shared.logout()                  // No-op currently

// Check subscription status (always returns free tier currently)
service.currentTier        // Always .free
service.isProSubscriber    // Always false
service.isTeamSubscriber   // Always false
service.isPaidSubscriber   // Always false
```

### Subscription Tiers (Planned)

| Tier | Projects | Feedback | Team Members | Integrations |
|------|----------|----------|--------------|--------------|
| Free | 1 | 10/project | No | No |
| Pro | 2 | Unlimited | No | No |
| Team | Unlimited | Unlimited | Unlimited | All (Slack, GitHub, Email) |

### SubscriptionTier Enum

```swift
enum SubscriptionTier: String, Codable, Sendable {
    case free, pro, team

    var maxProjects: Int?           // nil = unlimited
    var maxFeedbackPerProject: Int? // nil = unlimited
    var canInviteMembers: Bool
    var hasIntegrations: Bool
    var hasAdvancedAnalytics: Bool
    var hasConfigurableStatuses: Bool

    func meetsRequirement(_ required: SubscriptionTier) -> Bool
}
```

### Planned Entitlement IDs (for RevenueCat)

- `"Swiftly Pro"` - Pro tier entitlement
- `"Swiftly Team"` - Team tier entitlement

### Planned Product IDs (for RevenueCat)

- `monthly` - Pro monthly subscription
- `yearly` - Pro yearly subscription
- `monthlyTeam` - Team monthly subscription
- `yearlyTeam` - Team yearly subscription

### UI Components

- `SubscriptionView.swift` - Subscription screen showing features and "Coming Soon" message
- `SettingsView.swift` - Subscription row in settings showing current tier

### Logging

Uses `AppLogger.subscription` category:

```swift
AppLogger.subscription.info("SubscriptionService initialized (stub mode)")
```

### Files

- `Services/SubscriptionService.swift` - Subscription service stub
- `Views/Settings/SubscriptionView.swift` - Subscription UI
- `Views/Settings/SettingsView.swift` - Settings with subscription section
- `Services/Logger.swift` - Subscription logging category

### TODO: Re-enable RevenueCat

To re-integrate RevenueCat when ready:
1. Add RevenueCat SPM package back to the project
2. Update `SubscriptionService.swift` to use RevenueCat SDK
3. Update `SubscriptionView.swift` to use PaywallView and CustomerCenterView
4. See `TODO_MONETIZATION.md` for full implementation checklist

## Monday.com Integration

Push feedback items to Monday.com as board items for tracking in your project management workflow.

### Setup
1. Get your Monday.com API token from Settings > Developers > My Access Tokens
2. In Admin app: Project Details > Menu (⋯) > Integrations > Monday.com
3. Enter your API token and select the target board via the picker
4. Optionally select a group and configure status sync, comment sync, and vote count sync

### MondaySettingsView Features
- API token SecureField
- Board picker: dynamically loads boards accessible to user
- Group picker: optionally select a group within the board
- Status column picker: select Status-type column for status sync
- Votes column picker: select Number-type column for vote count sync
- Status sync toggle: auto-update Monday.com item status when feedback status changes
- Comment sync toggle: sync comments to Monday.com items as updates
- Remove integration button

### Status Mapping
When status sync is enabled:
- **pending** → "Pending"
- **approved** → "Approved"
- **in_progress** → "Working on it"
- **testflight** → "In Review"
- **completed** → "Done"
- **rejected** → "Stuck"

### Feedback Context Menu Actions
- **Push to Monday**: Create a Monday.com item from feedback (only shown if Monday configured and no existing item)
- **View Monday Item**: Open the linked item in browser (only shown if feedback has an item)

### Bulk Actions
When selecting multiple feedback items, the action bar includes "Monday" button to create items for all selected items that don't already have Monday.com items.

### Visual Indicators
- Red Monday.com badge (calendar icon) on feedback cards that have linked items
- Success toast showing item creation when created

### Files
- `MondaySettingsView.swift` - Settings sheet for Monday.com integration with board picker
- `FeedbackDashboardView.swift` - Context menu with Push/View Monday actions
- `FeedbackListView.swift` - Row context menu with Monday actions, MondayBadge component
- `FeedbackViewModel.swift` - `createMondayItem()` and `bulkCreateMondayItems()` methods
- `ProjectViewModel.swift` - `updateMondaySettings()`, `loadMondayBoards()`, `loadMondayGroups()`, `loadMondayColumns()` methods
- `AdminAPIClient.swift` - All Monday.com API calls (settings, items, boards)
- `ProjectModels.swift` - Monday.com request/response DTOs

## Linear Integration

Push feedback items to Linear as issues for tracking in your product development workflow.

### Setup
1. Get your Linear Personal API Key from Settings > API
2. In Admin app: Project Details > Menu (⋯) > Integrations > Linear
3. Enter your API token and select the target team via the picker
4. Optionally select a project and configure default labels, status sync, and comment sync

### LinearSettingsView Features
- API token SecureField
- Team picker: dynamically loads teams accessible to user
- Project picker: optionally select a project within the team
- Labels picker: select default labels to apply to all issues
- Status sync toggle: auto-update Linear issue workflow state when feedback status changes
- Comment sync toggle: sync comments to Linear issues
- Remove integration button

### Status Mapping
When status sync is enabled, feedback status maps to Linear workflow state types:
- **pending** → `backlog`
- **approved** → `unstarted`
- **in_progress** → `started`
- **testflight** → `started`
- **completed** → `completed`
- **rejected** → `canceled`

Note: Linear finds the matching workflow state by type within the configured team.

### Feedback Context Menu Actions
- **Push to Linear**: Create a Linear issue from feedback (only shown if Linear configured and no existing issue)
- **View Linear Issue**: Open the linked issue in browser (only shown if feedback has an issue)

### Bulk Actions
When selecting multiple feedback items, the action bar includes "Push to Linear" button to create issues for all selected items that don't already have Linear issues.

### Visual Indicators
- Purple Linear badge (lineweight icon) on feedback cards that have linked issues
- Success toast showing issue identifier (e.g., "ENG-123") when created

### Files
- `LinearSettingsView.swift` - Settings sheet for Linear integration with team picker
- `FeedbackDashboardView.swift` - Context menu with Push/View Linear actions
- `FeedbackListView.swift` - Row context menu with Linear actions, LinearBadge component
- `FeedbackViewModel.swift` - `createLinearIssue()` and `bulkCreateLinearIssues()` methods
- `ProjectViewModel.swift` - `updateLinearSettings()`, `loadLinearTeams()`, `loadLinearProjects()`, `loadLinearLabels()` methods
- `AdminAPIClient.swift` - All Linear API calls (settings, issues, teams)
- `ProjectModels.swift` - Linear request/response DTOs
