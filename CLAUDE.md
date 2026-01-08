# CLAUDE.md - Feedback Kit

> **Note**: See [AGENTS.md](./AGENTS.md) for Swift and SwiftUI coding guidelines.

## Project Overview

Feedback Kit is a feedback collection platform with:
- **SwiftlyFeedbackServer** - Vapor backend with PostgreSQL
- **SwiftlyFeedbackKit** - Swift SDK with SwiftUI views (iOS/macOS/visionOS)
- **SwiftlyFeedbackAdmin** - Admin app for managing feedback
- **SwiftlyFeedbackDemoApp** - Demo app showcasing the SDK

Each subproject has its own `CLAUDE.md` with detailed documentation.

## Tech Stack

- **Language**: Swift 6.0
- **Backend**: Vapor 4, Fluent ORM, PostgreSQL
- **Auth**: Token-based with bcrypt
- **Platforms**: iOS 15+, macOS 12+, visionOS 1+
- **Testing**: Swift Testing (`@Test`) + XCTest

## Quick Start

```bash
open Swiftlyfeedback.xcworkspace

# Database (Docker)
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres

# Server
cd SwiftlyFeedbackServer && swift run
```

## Authorization Model

**Project Roles:**
- **Owner**: Full access (delete, archive, manage members, regenerate API key)
- **Admin**: Manage settings/members, update/delete feedback
- **Member**: View and respond to feedback
- **Viewer**: Read-only

**Key Rules:**
- Archived projects: reads allowed, writes blocked
- Voting blocked on `completed`/`rejected` status feedback
- `FeedbackStatus.canVote` indicates votability

## Feedback Statuses

| Status | Color | Can Vote |
|--------|-------|----------|
| pending | Gray | Yes |
| approved | Blue | Yes |
| in_progress | Orange | Yes |
| testflight | Cyan | Yes |
| completed | Green | No |
| rejected | Red | No |

Statuses are configurable per-project via Admin app or `PATCH /projects/:id/statuses`.

## SDK Configuration

```swift
// Basic setup
SwiftlyFeedback.configure(apiKey: "sf_...", baseURL: URL(string: "https://...")!)

// Disable submission (e.g., free users)
SwiftlyFeedback.config.allowFeedbackSubmission = false
SwiftlyFeedback.config.feedbackSubmissionDisabledMessage = "Upgrade to Pro!"

// Disable logging
SwiftlyFeedback.config.loggingEnabled = false

// Event tracking
SwiftlyFeedback.view("feature_details", properties: ["id": "123"])
SwiftlyFeedback.config.enableAutomaticViewTracking = false
```

## Swift 6 Concurrency

Admin app uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Key patterns:

```swift
// DTOs must be nonisolated for Codable from any actor
nonisolated struct Feedback: Codable, Sendable { ... }

// Thread-safe services opt out
nonisolated enum KeychainService { ... }

// Global state flags
nonisolated(unsafe) private var _loggingEnabled = true
```

**Common fixes:**
- "Codable cannot be used in actor-isolated context" → Add `nonisolated` to type
- "Static method cannot be called from outside actor" → Mark type as `nonisolated`

## Integrations

All integrations support: create/bulk create, status sync, comment sync, link tracking, and active toggles.

| Integration | Push To | Status Sync | Extra Features |
|-------------|---------|-------------|----------------|
| Slack | Webhook | N/A | Notifications (new feedback, comments, status changes) |
| GitHub | Issues | Close/reopen | Labels |
| Notion | Database pages | Status property | Votes property |
| ClickUp | Tasks | Status | Tags, votes custom field |
| Linear | Issues | Workflow states | Labels, projects |
| Monday.com | Board items | Status column | Votes column |

**Status mapping** (all integrations follow similar pattern):
- pending → backlog/to do
- approved → approved/unstarted
- in_progress → in progress/started
- completed → complete/done
- rejected → closed/canceled

Configure via Admin app: Project Details > Menu (⋯) > [Integration] Integration.

See `SwiftlyFeedbackServer/CLAUDE.md` for API endpoints and request/response formats.

## Email Notifications

Via Resend API. User preferences in Settings:
- `notifyNewFeedback` / `notifyNewComments`

**Types:** New feedback, new comments, status changes, email verification, project invites, password reset.

## Password Reset

1. User requests reset via email
2. Server sends 8-char code (1-hour expiry)
3. User enters code + new password
4. All sessions invalidated

## Feedback Merging

Select 2+ feedback items → Merge. Primary keeps title/description, votes are de-duplicated, comments migrated with prefix. Secondary items soft-deleted.

`POST /feedbacks/merge` with `primary_feedback_id` and `secondary_feedback_ids[]`.

## Onboarding Flow (Admin App)

1. Welcome → 2. Create Account → 3. Verify Email → 4. Project Choice → 5. Create/Join Project → 6. Completion

`OnboardingManager` singleton tracks state in `UserDefaults`.

## Developer Commands (Admin App)

Available in DEBUG and TestFlight builds only. Access via:
- **macOS**: Menu bar → Feedback Kit → Developer Commands... (⌘⇧D)
- **iOS**: Settings → Developer section

**Features:**
- Generate dummy projects, feedback, and comments
- Reset onboarding, auth token, UserDefaults
- Clear project feedback, delete all projects
- Full database reset (DEBUG only - not available in TestFlight)

Controlled by `AppEnvironment.isDeveloperMode` (DEBUG || TestFlight) and `AppEnvironment.isDebug`.

## Analytics

- **Events**: `POST /events/track`, `GET /events/project/:id/stats?days=N`
- **Users**: Auto-registered on SDK init, tracks first/last seen, MRR
- **Dashboard**: Home tab shows KPIs, feedback by status, per-project stats
- **MRR**: Displayed on feedback cards, sortable

## Project Icons

`colorIndex` (0-7) maps to gradient pairs. Archived projects show gray.

## Code Conventions

- `@main` for entry points
- `@Observable` + `Bindable()` for state
- `#Preview` macro for previews
- `@Test` macro for tests
- Models: `Codable`, `Sendable`, `Equatable`
- Platform: `#if os(macOS)` / `#if os(iOS)`

## Monetization (Planned)

RevenueCat integration not yet complete. All users on Free tier.

| Tier | Projects | Feedback | Members | Integrations |
|------|----------|----------|---------|--------------|
| Free | 1 | 10/project | No | No |
| Pro | 2 | Unlimited | No | No |
| Team | Unlimited | Unlimited | Yes | Yes |
