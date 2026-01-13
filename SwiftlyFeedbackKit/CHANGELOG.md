# Changelog

All notable changes to FeedbackKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-13

### Added

#### Core Features
- **FeedbackListView** - Ready-to-use SwiftUI view displaying all feedback with sorting and filtering
- **SubmitFeedbackView** - Form for users to submit new feedback with title, description, category, and optional email
- **FeedbackDetailView** - Detailed view showing feedback information, vote button, and comments
- **FeedbackRowView** - Reusable row component for displaying feedback in lists

#### Voting System
- Upvote/downvote functionality with `vote(for:)` and `unvote(for:)` methods
- Configurable undo vote behavior via `allowUndoVote`
- Vote count display with `showVoteCount` toggle

#### Voter Email Notifications
- Optional email collection when voting for status change notifications
- `userEmail` configuration for pre-setting user email
- `showVoteEmailField` to control email dialog display
- `voteNotificationDefaultOptIn` for default toggle state
- `onUserEmailChanged` callback for syncing email back to host app
- One-click unsubscribe via unique permission keys

#### Comments
- View comments on feedback items
- Add comments via `addComment(to:content:)`
- Configurable visibility with `showCommentSection`

#### Configuration
- `SwiftlyFeedback.configure(with:)` for localhost development
- `SwiftlyFeedback.configureAuto(with:)` for automatic environment detection
- `SwiftlyFeedback.configure(with:baseURL:)` for custom server URLs
- Feature toggles for UI elements (badges, buttons, form fields)
- `allowFeedbackSubmission` with custom disabled message for paywalls

#### Theming
- `SwiftlyFeedbackTheme` for customizing colors
- `ThemeColor` enum supporting light/dark mode adaptation
- Per-status color customization via `StatusColors`
- Per-category color customization via `CategoryColors`
- Full dark mode support

#### User Identification
- Automatic unique user ID generation stored in Keychain
- Custom user ID support via `updateUser(customID:)`
- MRR tracking with `updateUser(payment:)` supporting weekly, monthly, quarterly, and yearly subscriptions

#### Event Tracking
- Automatic view tracking for SDK screens
- Custom event tracking via `SwiftlyFeedback.view(_:properties:)`
- Configurable with `enableAutomaticViewTracking`

#### Error Handling
- `SwiftlyFeedbackError` enum with typed errors:
  - `invalidResponse`, `badRequest`, `unauthorized`, `invalidApiKey`
  - `notFound`, `conflict`, `serverError`, `networkError`
  - `decodingError`, `feedbackLimitReached`

#### Platform Support
- iOS 26.0+
- macOS 26.0+ with keyboard shortcuts (Command+Return to submit)
- visionOS 26.0+

#### Developer Experience
- OSLog-based logging with configurable `loggingEnabled`
- Thread-safe API client using Swift actors
- Full Swift 6 concurrency support with `Sendable` conformance

### Models
- `Feedback` - Core feedback model with status, category, votes, and metadata
- `FeedbackStatus` - Enum: pending, approved, in_progress, testflight, completed, rejected
- `FeedbackCategory` - Enum: featureRequest, bugReport, improvement, other
- `Comment` - Comment model with author and timestamp
- `VoteResult` - Vote operation response with updated counts

[1.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.0.0
