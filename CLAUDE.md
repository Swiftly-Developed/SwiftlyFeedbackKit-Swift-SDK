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
