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
│   └── SDKUserModels.swift         # SDK user and stats models
├── ViewModels/
│   ├── AuthViewModel.swift         # Authentication state
│   ├── ProjectViewModel.swift      # Project management state
│   ├── FeedbackViewModel.swift     # Feedback management state
│   └── SDKUserViewModel.swift      # SDK user management state
├── Views/
│   ├── RootView.swift              # Root navigation
│   ├── MainTabView.swift           # Tab bar navigation
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
│   │   └── AcceptInviteView.swift     # Accept project invite
│   ├── Feedback/
│   │   ├── FeedbackDashboardView.swift # Dashboard with List/Kanban views
│   │   ├── FeedbackListView.swift      # Feedback list with row view
│   │   └── FeedbackDetailView.swift    # Feedback detail with comments
│   ├── Users/
│   │   ├── UsersDashboardView.swift    # Users dashboard with stats and list
│   │   └── UsersListView.swift         # Users list (legacy, used in project detail)
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
