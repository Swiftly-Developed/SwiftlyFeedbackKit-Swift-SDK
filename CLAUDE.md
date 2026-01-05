# CLAUDE.md - SwiftlyFeedback

> **Note**: Also see [AGENTS.md](./AGENTS.md) for Swift and SwiftUI coding guidelines.

## Project Overview

SwiftlyFeedback is a feedback collection and management platform consisting of:

- **SwiftlyFeedbackServer** - Vapor backend API server with PostgreSQL database
- **SwiftlyFeedbackKit** - Swift client SDK with SwiftUI views for iOS/macOS/visionOS
- **SwiftlyFeedbackAdmin** - Admin application for managing feedback
- **SwiftlyFeedbackDemoApp** - Demo application showcasing the SDK

Each project has its own `CLAUDE.md` with project-specific details.

## Tech Stack

- **Language**: Swift 6.0
- **Backend**: Vapor 4 with Fluent ORM and PostgreSQL
- **Authentication**: Token-based authentication with bcrypt password hashing
- **Client SDK**: Swift Package with SwiftUI views
- **Platforms**: iOS 15+, macOS 12+, visionOS 1+
- **Testing**: Swift Testing (`@Test` macro) + XCTest

## Directory Structure

```
SwiftlyFeedback/
├── Swiftlyfeedback.xcworkspace/      # Shared workspace (open this)
├── SwiftlyFeedbackServer/            # Vapor backend (see its CLAUDE.md)
├── SwiftlyFeedbackKit/               # Client SDK (see its CLAUDE.md)
├── SwiftlyFeedbackAdmin/             # Admin app (see its CLAUDE.md)
└── SwiftlyFeedbackDemoApp/           # Demo app (see its CLAUDE.md)
```

## Quick Start

```bash
# Open workspace
open Swiftlyfeedback.xcworkspace

# Start database (Docker)
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres

# Run server
cd SwiftlyFeedbackServer && swift run
```

## Authorization Model

### Project Roles
- **Owner**: Full access - delete project, archive/unarchive, manage members, regenerate API key
- **Admin**: Manage project settings and members, update/delete feedback
- **Member**: View feedback and respond
- **Viewer**: Read-only access

### Archive Behavior
- Archived projects allow reads but block new feedback, votes, and comments
- Only owner can archive/unarchive

### Voting Restrictions
- Users cannot vote on feedback with **completed** or **rejected** status
- Server returns 403 Forbidden if voting is attempted on these statuses
- SDK disables and dims the vote button for non-votable feedback
- `FeedbackStatus.canVote` property indicates if voting is allowed

### Configurable Feedback Statuses
Projects can customize which statuses are available for feedback. This allows enabling/disabling specific workflow stages like TestFlight.

**Available Statuses:**
| Status | Raw Value | Color | Can Vote | Description |
|--------|-----------|-------|----------|-------------|
| Pending | `pending` | Gray | Yes | Default new feedback status (always required) |
| Approved | `approved` | Blue | Yes | Acknowledged by team |
| In Progress | `in_progress` | Orange | Yes | Currently being worked on |
| TestFlight | `testflight` | Cyan | Yes | Available for testing |
| Completed | `completed` | Green | No | Done - voting blocked |
| Rejected | `rejected` | Red | No | Not accepted - voting blocked |

**Configuration:**
- Configure via Admin app: Project Details > Menu (⋯) > Status Settings
- Toggle optional statuses on/off (pending is always required)
- Default: pending, approved, in_progress, completed, rejected

**Server Endpoint:**
- `PATCH /projects/:id/statuses` - Update allowed statuses (bearer auth, owner/admin only)

Request body:
```json
{
  "allowed_statuses": ["pending", "approved", "in_progress", "testflight", "completed", "rejected"]
}
```

**Database Field (Project model):**
- `allowed_statuses` ([String]) - Array of allowed status raw values

### Feedback Submission Permission
The SDK supports restricting feedback submission (e.g., for free users):

```swift
// Disable feedback submission for free users
SwiftlyFeedback.config.allowFeedbackSubmission = user.isPro

// Customize the alert message shown when submission is disabled
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage =
    "Only Pro users can submit feature requests, but you can vote for existing ones!"
```

**Behavior when disabled:**
- The add button remains visible but shows an alert instead of opening the submission form
- Alert title: "Submission Disabled" (localized)
- Alert message: Custom message or default "Feedback submission is not available. You can still vote for existing feedback."
- Users can still browse and vote on existing feedback

### SDK Logging

The SDK outputs debug information to the console via OSLog. To prevent console clutter, logging can be disabled:

```swift
// Disable SDK logging
SwiftlyFeedback.config.loggingEnabled = false
```

**Behavior:**
- When `true` (default): SDK logs API requests, responses, and errors to the console
- When `false`: All SDK logging is suppressed
- Uses OSLog with subsystem `com.swiftlyfeedback.sdk`

### Admin App Logging

The Admin app also has configurable logging via `AppLogger`:

```swift
// Disable Admin app logging
AppLogger.isEnabled = false
```

See [SwiftlyFeedbackAdmin/CLAUDE.md](SwiftlyFeedbackAdmin/CLAUDE.md) for full logging documentation with category details.

## Analytics & Tracking

### View Event Tracking
The SDK tracks user views and custom events. Events are stored with user ID, event name, and optional properties.

**SDK Usage:**
```swift
// Track custom events (any string - fully customizable)
SwiftlyFeedback.view("feature_details", properties: ["id": "abc123"])
SwiftlyFeedback.view("onboarding_step_1")
SwiftlyFeedback.view("purchase_completed", properties: ["amount": "9.99"])

// Predefined events (automatically tracked when views appear)
SwiftlyFeedback.view(.feedbackList)
SwiftlyFeedback.view(.feedbackDetail)
SwiftlyFeedback.view(.submitFeedback)

// Disable automatic tracking
SwiftlyFeedback.config.enableAutomaticViewTracking = false
```

**Server Endpoints:**
- `POST /events/track` - Track event (SDK, API key auth)
- `GET /events/project/:id/stats?days=N` - Event statistics with daily breakdown (Admin, bearer auth)
- `GET /events/all/stats?days=N` - Aggregated event statistics across all projects (Admin, bearer auth)
- `GET /events/project/:id` - Recent events (Admin, bearer auth)

**Time Period Filter:**
The Events dashboard supports flexible time period filtering:
- **Presets**: Last 7 Days, Last 30 Days (default), Last 90 Days, Last Year
- **Custom**: Any value + unit (Days, Weeks, Months, Years)
- Query parameter: `?days=N` (max 365)
- Platform-specific UI: iOS uses sheet with list/stepper, macOS uses popover with buttons/text field

**Admin Dashboard:**
- Events tab displays total events, unique users, and event breakdown by type
- Daily events chart (Swift Charts) shows event history for selected time period
- Time period picker in toolbar with presets and custom period option
- Recent events list with user type indicators (iCloud/Device/Custom)

### SDK User Tracking
- Users are automatically registered on SDK initialization
- Tracks first seen, last seen, and MRR (Monthly Recurring Revenue)
- User IDs: iCloud-based (`icloud_`), local UUID (`local_`), or custom

### Feedback MRR Display
The Admin app displays total MRR (Monthly Recurring Revenue) on feedback cards to help identify which features are most requested by paying customers.

**How it works:**
- Each feedback item shows a green MRR badge (e.g., "$20", "$0")
- Total MRR is calculated as: feedback creator's MRR + all voters' MRR
- MRR values come from the SDK user tracking (set via `SwiftlyFeedback.setMrr()`)

**Sorting by MRR:**
- Feedback can be sorted by MRR via the filter menu → "Sort by" → "MRR"
- Sorts highest MRR first to prioritize feedback from paying customers
- Other sort options: Votes, Newest, Oldest

**Where MRR is displayed:**
- Feedback list view (list rows)
- Kanban view (cards)
- Feedback detail view (header section)

### Home Dashboard (KPIs)
The Admin app includes a Home dashboard with key performance indicators (KPIs) across all projects.

**Features:**
- Global KPIs: Projects count, total feedback, users, comments, and votes
- Feedback breakdown by status: Pending, Approved, In Progress, Completed, Rejected
- Per-project statistics with mini status badges
- Toolbar project filter to view stats for all projects or a specific project

**Server Endpoints:**
- `GET /dashboard/home` - Aggregated statistics across all user's projects (bearer auth)
- `GET /dashboard/project/:id` - Statistics for a specific project (bearer auth)

**Admin Dashboard:**
- Home tab (first tab) displays overview KPIs with stat cards
- Status breakdown section shows feedback counts by status
- Projects section lists all projects with feedback/user/comment/vote counts
- Project picker in toolbar filters all stats by selected project

### Shared Project Filter
The Admin app maintains a shared project filter across multiple tabs:
- **Feedback**, **Users**, and **Events** tabs share the same project selection
- Selecting "All Projects" or a specific project persists when switching tabs
- Implemented via `selectedFilterProject` property on `ProjectViewModel`
- Uses `.task(id:)` modifier for reactive data loading when filter changes

## Project Icons

Projects have customizable icon colors stored in the database:
- `colorIndex` (0-7) maps to predefined gradient color pairs
- Generated randomly on project creation
- Users can change colors via Edit Project in the Admin app
- Archived projects always display gray icons regardless of colorIndex

Available gradients (index 0-7):
0. Blue → Purple
1. Green → Teal
2. Orange → Red
3. Pink → Purple
4. Indigo → Blue
5. Teal → Cyan
6. Purple → Pink
7. Mint → Green

## Email Notifications

Email notifications are sent via Resend API when certain events occur. Users can configure their notification preferences in the Admin app Settings.

### Notification Settings
Users have individual notification preferences stored on their account:
- `notifyNewFeedback` - Receive emails when new feedback is submitted (default: true)
- `notifyNewComments` - Receive emails when comments are added (default: true)

Settings can be updated via:
- Admin app: Settings → Notifications section with toggle switches
- API: `PATCH /auth/notifications` with bearer token auth

### New Feedback Notification
When a user submits new feedback via the SDK, project members with `notifyNewFeedback` enabled receive an email containing:
- Project name
- Feedback category (feature request, bug report, etc.)
- Feedback title
- Truncated description (max 200 characters)

### New Comment Notification
When a comment is added to feedback, project members with `notifyNewComments` enabled receive an email containing:
- Project name
- Feedback title
- Comment content (max 300 characters)
- Commenter type (Admin/User)

### Feedback Status Change Notification
When an admin changes a feedback's status (e.g., pending → approved → in progress → completed), users who submitted the feedback (and provided an email) receive a notification containing:
- Project name
- Feedback title
- Old status → New status transition
- Status-specific message (e.g., "Work has started on your feedback")
- Status emoji indicator (✅ approved, 🔄 in progress, 🎉 completed, ❌ rejected)

Note: Currently only feedback submitters with emails are notified. To notify voters, add a `userEmail` field to the Vote model.

All notification emails are sent asynchronously to avoid blocking API responses.

### Other Email Types
- **Email Verification**: Sent on user signup with 8-character verification code
- **Project Invite**: Sent when inviting members to a project with invite code

## Slack Integration

Projects can optionally send notifications to a Slack channel via Incoming Webhooks. Configuration is done per-project in the Admin app.

### Setup
1. In your Slack workspace, create an Incoming Webhook (Apps & Integrations > Incoming Webhooks)
2. Copy the webhook URL (starts with `https://hooks.slack.com/`)
3. In Admin app: Project Details > Menu (⋯) > Slack Integration
4. Paste the webhook URL and configure notification preferences

### Notification Types
Each notification type can be enabled/disabled independently:
- **New feedback** (`slackNotifyNewFeedback`): When users submit new feedback via the SDK
- **New comments** (`slackNotifyNewComments`): When comments are added to feedback
- **Status changes** (`slackNotifyStatusChanges`): When feedback status is updated (pending → approved → in progress → completed/rejected)

### Message Format
Slack notifications use Block Kit for rich formatting:
- Header with notification type
- Project name
- Relevant details (feedback title, category, description, status change, comment content)
- Status emojis for status changes

### Server Endpoint
- `PATCH /projects/:id/slack` - Update Slack settings (bearer auth, owner/admin only)

Request body:
```json
{
  "slack_webhook_url": "https://hooks.slack.com/...",
  "slack_notify_new_feedback": true,
  "slack_notify_new_comments": true,
  "slack_notify_status_changes": true
}
```

### Database Fields (Project model)
- `slack_webhook_url` (String?, optional) - Slack Incoming Webhook URL
- `slack_notify_new_feedback` (Bool, default: true) - Enable new feedback notifications
- `slack_notify_new_comments` (Bool, default: true) - Enable comment notifications
- `slack_notify_status_changes` (Bool, default: true) - Enable status change notifications

All Slack notifications are sent asynchronously to avoid blocking API responses.

## GitHub Integration

Projects can push feedback items to GitHub as issues for tracking in your development workflow. Configuration is done per-project in the Admin app.

### Setup
1. Create a GitHub Personal Access Token (PAT) with `repo` scope (private repos) or `public_repo` scope (public repos)
2. In Admin app: Project Details > Menu (⋯) > GitHub Integration
3. Enter repository owner, name, and token
4. Optionally configure default labels and status sync

### Features
- **Create Issue**: Push individual feedback to GitHub as an issue
- **Bulk Create**: Push multiple selected feedback items at once
- **Status Sync**: Automatically close/reopen issues when feedback status changes
- **Link Tracking**: GitHub issue URL stored on feedback for quick access

### Issue Creation
When feedback is pushed to GitHub:
- Issue title = Feedback title
- Issue body includes description, category, vote count, MRR, and submitter email
- Labels: default labels + feedback category (e.g., "feature_request", "bug")
- Feedback card shows GitHub badge with link to issue

### Status Sync (Optional)
When enabled, feedback status changes sync to GitHub:
- **Completed/Rejected** → Issue closed
- **Other status** (from completed/rejected) → Issue reopened

### Server Endpoints
- `PATCH /projects/:id/github` - Update GitHub settings (bearer auth, owner/admin only)
- `POST /projects/:id/github/issue` - Create single issue (bearer auth, owner/admin only)
- `POST /projects/:id/github/issues` - Bulk create issues (bearer auth, owner/admin only)

**Update settings request:**
```json
{
  "github_owner": "apple",
  "github_repo": "swift",
  "github_token": "ghp_...",
  "github_default_labels": ["feedback", "user-request"],
  "github_sync_status": true
}
```

**Create issue request:**
```json
{
  "feedback_id": "uuid",
  "additional_labels": ["priority-high"]
}
```

**Create issue response:**
```json
{
  "feedback_id": "uuid",
  "issue_url": "https://github.com/owner/repo/issues/123",
  "issue_number": 123
}
```

### Database Fields

**Project model:**
- `github_owner` (String?, optional) - Repository owner (user or org)
- `github_repo` (String?, optional) - Repository name
- `github_token` (String?, optional) - Personal Access Token
- `github_default_labels` ([String]?, optional) - Labels applied to all issues
- `github_sync_status` (Bool, default: false) - Enable status sync

**Feedback model:**
- `github_issue_url` (String?, optional) - URL of linked GitHub issue
- `github_issue_number` (Int?, optional) - Issue number for API calls

### Admin App UI
- **Settings**: Project Details > Menu (⋯) > GitHub Integration
- **Push single**: Right-click feedback > "Push to GitHub"
- **Push bulk**: Select multiple items > "Push to GitHub" button in action bar
- **View issue**: Right-click feedback with issue > "View GitHub Issue"
- **Badge**: Feedback cards show GitHub icon when linked to an issue

## ClickUp Integration

Projects can push feedback items to ClickUp as tasks for tracking in your project management workflow. Configuration is done per-project in the Admin app.

### Setup
1. Get your ClickUp API token from Settings > Apps in ClickUp
2. In Admin app: Project Details > Menu (⋯) > ClickUp Integration
3. Enter your API token and select the target list via the hierarchy picker
4. Optionally configure default tags, status sync, comment sync, and vote count sync

### Features
- **Create Task**: Push individual feedback to ClickUp as a task
- **Bulk Create**: Push multiple selected feedback items at once
- **Status Sync**: Automatically update ClickUp task status when feedback status changes
- **Comment Sync**: Sync comments from SwiftlyFeedback to ClickUp tasks
- **Vote Count Sync**: Update a custom field with vote count when users vote
- **Link Tracking**: ClickUp task URL stored on feedback for quick access

### Task Creation
When feedback is pushed to ClickUp:
- Task name = Feedback title
- Task description (markdown) includes description, category, vote count, MRR, and submitter email
- Tags: default tags + feedback category (e.g., "feature_request", "bug_report")
- Feedback card shows ClickUp badge with link to task

### Status Sync (Optional)
When enabled, feedback status changes map to ClickUp statuses:
- **pending** → "to do"
- **approved** → "approved"
- **in_progress** → "in progress"
- **testflight** → "in review"
- **completed** → "complete"
- **rejected** → "closed"

### Server Endpoints
- `PATCH /projects/:id/clickup` - Update ClickUp settings (bearer auth, owner/admin only)
- `POST /projects/:id/clickup/task` - Create single task (bearer auth, owner/admin only)
- `POST /projects/:id/clickup/tasks` - Bulk create tasks (bearer auth, owner/admin only)
- `GET /projects/:id/clickup/workspaces` - Get workspaces for hierarchy picker
- `GET /projects/:id/clickup/spaces/:workspaceId` - Get spaces
- `GET /projects/:id/clickup/folders/:spaceId` - Get folders
- `GET /projects/:id/clickup/lists/:folderId` - Get lists in folder
- `GET /projects/:id/clickup/folderless-lists/:spaceId` - Get lists without folder
- `GET /projects/:id/clickup/custom-fields` - Get number fields for vote count

**Update settings request:**
```json
{
  "clickup_token": "pk_...",
  "clickup_list_id": "12345",
  "clickup_workspace_name": "My Workspace",
  "clickup_list_name": "Feedback",
  "clickup_default_tags": ["feedback", "user-request"],
  "clickup_sync_status": true,
  "clickup_sync_comments": true,
  "clickup_votes_field_id": "abc123"
}
```

**Create task request:**
```json
{
  "feedback_id": "uuid",
  "additional_tags": ["priority-high"]
}
```

**Create task response:**
```json
{
  "feedback_id": "uuid",
  "task_url": "https://app.clickup.com/t/123abc",
  "task_id": "123abc"
}
```

### Database Fields

**Project model:**
- `clickup_token` (String?, optional) - ClickUp API token
- `clickup_list_id` (String?, optional) - Target list ID
- `clickup_workspace_name` (String?, optional) - Workspace name for display
- `clickup_list_name` (String?, optional) - List name for display
- `clickup_default_tags` ([String]?, optional) - Tags applied to all tasks
- `clickup_sync_status` (Bool, default: false) - Enable status sync
- `clickup_sync_comments` (Bool, default: false) - Enable comment sync
- `clickup_votes_field_id` (String?, optional) - Custom field ID for vote count

**Feedback model:**
- `clickup_task_url` (String?, optional) - URL of linked ClickUp task
- `clickup_task_id` (String?, optional) - Task ID for API calls

### Admin App UI
- **Settings**: Project Details > Menu (⋯) > ClickUp Integration
- **Push single**: Right-click feedback > "Push to ClickUp"
- **Push bulk**: Select multiple items > "Push to ClickUp" button in action bar
- **View task**: Right-click feedback with task > "View ClickUp Task"
- **Badge**: Feedback cards show purple ClickUp badge when linked to a task

## Feedback Merging

Admins can merge duplicate feedback items to consolidate similar requests. This helps get an accurate picture of demand while keeping vote counts and comments organized.

### How Merging Works
1. **Selection Mode**: In the Admin app feedback list, tap "Select" to enter selection mode
2. **Select Feedbacks**: Tap multiple feedback items to select them (minimum 2 required)
3. **Merge Button**: A floating action bar appears with the "Merge" button
4. **Primary Selection**: Choose which feedback becomes the "primary" that survives the merge
5. **Confirm**: Review the combined stats and confirm the merge

### What Happens During Merge
- **Primary feedback** keeps its title, description, category, and status
- **Votes** are consolidated (de-duplicated by userId - no double-counting)
- **Comments** are migrated with context prefix: "[Originally on: {title}] {content}"
- **Vote count** is recalculated based on unique voters
- **Secondary feedbacks** are soft-deleted (marked as merged, not hard deleted)
- **MRR** is recalculated based on all unique voters

### Database Fields (Feedback model)
- `merged_into_id` (UUID?, optional) - Points to primary feedback if this was merged
- `merged_at` (Date?, optional) - When the merge occurred
- `merged_feedback_ids` ([UUID]?, optional) - For primary: IDs of feedback merged into this

### Server Endpoint
- `POST /feedbacks/merge` - Merge feedback items (bearer auth, owner/admin only)

Request body:
```json
{
  "primary_feedback_id": "uuid",
  "secondary_feedback_ids": ["uuid", "uuid"]
}
```

Response:
```json
{
  "primary_feedback": { ... },
  "merged_count": 2,
  "total_votes": 25,
  "total_comments": 8
}
```

### Admin App UI
- **Selection mode**: Toggle via "Select" toolbar button
- **Merge badge**: Purple badge showing merged count on feedback that received merges
- **Merge history**: Detail view shows list of merged feedback IDs

### SDK Support
- `mergedIntoId` field on Feedback model indicates if feedback was merged
- `isMerged` computed property for easy checking
- Merged feedback is filtered out from default list queries (`?includeMerged=true` to include)

## Demo App

The SwiftlyFeedbackDemoApp showcases SDK integration patterns:

**Features:**
- Platform-adaptive navigation: TabView (iOS) / NavigationSplitView (macOS)
- Home screen explaining SwiftlyFeedback features
- Settings screen demonstrating all SDK configuration options
- User profile with email/name/custom ID
- Subscription/MRR tracking with billing cycle picker
- SDK configuration toggles (vote undo, comments, badges, etc.)
- Settings persistence via UserDefaults with `@Observable`

**Usage Pattern:**
```swift
// Use Bindable() for bindings with @Observable classes
TextField("Name", text: Bindable(settings).userName)
Toggle("Feature", isOn: Bindable(settings).featureEnabled)
```

## Monetization (Planned)

SwiftlyFeedback will use RevenueCat for subscription management. The implementation is **not yet complete** - see `TODO_MONETIZATION.md` for remaining tasks.

**Current Status:** RevenueCat SDK is not integrated. All users are on the Free tier. The subscription UI shows a "Coming Soon" message.

### Subscription Tiers (Planned)

| Tier | Monthly | Yearly | Projects | Feedback | Team Members | Integrations |
|------|---------|--------|----------|----------|--------------|--------------|
| Free | $0 | $0 | 1 | 10/project | None | None |
| Pro | $15 | $150 | 2 | Unlimited | None | None |
| Team | $39 | $390 | Unlimited | Unlimited | Unlimited | All |

### Feature Matrix (Planned)

| Feature | Free | Pro | Team |
|---------|------|-----|------|
| Create projects | 1 | 2 | Unlimited |
| Feedback items per project | 10 | Unlimited | Unlimited |
| Invite team members | No | No | Yes |
| Slack/GitHub/Email integrations | No | No | Yes |
| Configurable statuses | No | Yes | Yes |
| MRR tracking/sorting | No | Yes | Yes |

### Current Implementation Status

**Completed (Admin App):**
- `SubscriptionService.swift` stub (returns free tier)
- `SubscriptionView.swift` with feature lists and "Coming Soon" message
- Settings integration with subscription row
- Auth flow hooks for future subscription sync
- Logging category for subscription events

**Not Yet Implemented:**
- RevenueCat SDK integration
- Server-side: Database schema, webhook handlers, feature limit enforcement
- Admin App: PaywallView, CustomerCenterView, feature gating UI
- SDK: 402 Payment Required error handling

See `SwiftlyFeedbackAdmin/CLAUDE.md` for detailed Admin app implementation docs.

### Planned RevenueCat Configuration

**Entitlements:**
- `"Swiftly Pro"` - Pro tier access
- `"Swiftly Team"` - Team tier access

**Products:**
- `monthly` / `yearly` - Pro subscriptions
- `monthlyTeam` / `yearlyTeam` - Team subscriptions

## Code Conventions

- Use `@main` attribute for app entry points
- Use SwiftUI declarative syntax with modifier chaining
- Use `#Preview` macro for SwiftUI previews
- Use Swift Testing (`@Test` macro) for unit tests
- Models are `Codable`, `Sendable`, and `Equatable`
- API client uses Swift concurrency (async/await)
- All user input is validated and trimmed
- Email validation uses regex pattern matching
- Passwords are hashed with bcrypt
- Use `Bindable()` for @Observable bindings instead of `@Bindable` property wrapper
- Platform conditionals: `#if os(macOS)` / `#if os(iOS)`

