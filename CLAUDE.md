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
- `GET /events/project/:id/stats` - Event statistics with 30-day daily breakdown (Admin, bearer auth)
- `GET /events/project/:id` - Recent events (Admin, bearer auth)

**Admin Dashboard:**
- Events tab displays total events, unique users, and event breakdown by type
- Daily events chart (Swift Charts) shows 30-day history with bar visualization
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
