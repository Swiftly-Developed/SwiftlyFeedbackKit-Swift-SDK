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
│   └── HomeDashboardViewModel.swift # Home dashboard state
├── Views/
│   ├── RootView.swift              # Root navigation
│   ├── MainTabView.swift           # Tab bar navigation
│   ├── Home/
│   │   └── HomeDashboardView.swift   # Home dashboard with KPIs
│   ├── Auth/
│   │   ├── AuthContainerView.swift    # Auth flow container
│   │   ├── LoginView.swift            # Login form
│   │   ├── SignupView.swift           # Signup form
│   │   └── EmailVerificationView.swift # Email verification screen
│   ├── Projects/
│   │   ├── ProjectListView.swift      # Project list with 3 view modes (list/table/grid)
│   │   ├── ProjectDetailView.swift    # Project details & feedback
│   │   ├── CreateProjectView.swift    # Create new project sheet
│   │   ├── ProjectMembersView.swift   # Manage members
│   │   ├── AcceptInviteView.swift     # Accept project invite
│   │   └── SlackSettingsView.swift    # Configure Slack webhook notifications
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

## Authentication Flow

1. User logs in via `LoginView` or signs up via `SignupView`
2. New users must verify email via `EmailVerificationView` (8-character code)
3. Token stored securely in Keychain via `KeychainService`
4. `AuthViewModel` manages authentication state including `needsEmailVerification`
5. `AdminAPIClient` includes Bearer token in requests

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

## Feedback Dashboard

The `FeedbackDashboardView` provides a dedicated tab for managing feedback across all projects:

### View Modes (persisted via `@AppStorage`)

| Mode | Icon | Description |
|------|------|-------------|
| List | `list.bullet` | Traditional list with swipe actions and context menus |
| Kanban | `rectangle.3.group` | Drag-and-drop columns by status (Pending, Approved, In Progress, Completed, Rejected) |

### Features
- Project picker in toolbar to switch between projects
- Search feedback by title, description, or user email
- Filter by status and/or category
- Update status via context menu, swipe actions, or drag-and-drop (Kanban)
- View feedback details and manage comments

## Users Dashboard

The `UsersDashboardView` provides a dedicated tab for viewing SDK users (end users of apps using SwiftlyFeedbackKit):

### Features
- Project picker in toolbar to switch between projects
- Stats cards showing: Total Users, Total MRR, Paying Users, Average MRR
- Search users by user ID
- Sort by: Last Seen, MRR, Feedback Count, Vote Count
- User list showing user type (iCloud/Device/Custom), activity stats, and MRR

### User Types
- **iCloud**: Users identified via iCloud (`icloud_` prefix)
- **Device**: Local device-based users (`local_` prefix)
- **Custom**: Custom user identifiers provided by the app

### Logging
Uses `Logger.swift` for centralized OSLog logging with categories:
- `Logger.api` - API requests/responses
- `Logger.viewModel` - ViewModel state changes
- `Logger.view` - View lifecycle events

## Developer Commands (DEBUG/TestFlight only)

`DeveloperCommandsView` is available in Settings when running in DEBUG or TestFlight builds:

- **Generate Dummy Projects**: Create test projects with random names
- **Generate Dummy Feedback**: Add test feedback items to a project
- **Generate Dummy Comments**: Add test comments to existing feedback
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
- Project picker in toolbar to switch between projects
- Stats cards showing: Total Events, Unique Users
- **Daily Events Chart** (Swift Charts) showing 30-day event history with bar visualization
- Event breakdown showing count and unique users per event type
- Recent events list with user type indicators (iCloud/Device/Custom)

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
