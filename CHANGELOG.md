# Changelog

All notable changes to FeedbackKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased

Major version bump per the SemVer policy in `SwiftlyFeedbackKit/CLAUDE.md`: this release removes and renames public API.

### Added

- Reader-side on-device translation of feedback content (iOS and macOS): titles, descriptions, rejection reasons, and comments written in another language are translated toward the device locale, with a per-item "Translated from ⟨language⟩" affordance and Show original / Show translation toggle on list cards, the detail header, and comment rows. Original text always paints first; translations never block rendering; failures fall back silently to the original. The affordance is absent — never disabled — on visionOS and for unsupported language pairs. Controlled by the `translationEnabled` configuration knob (default on), backed by internal infrastructure (source-language detection, per-source batching, in-memory caching — never persisted).
- Feedback list search: a search field with free-text matching over titles and descriptions plus suggested status and category tokens, and a dedicated "no results" empty state with a clear-search action.
- Feedback list loading and error states: a skeleton placeholder during initial loads (with a 150 ms no-flash grace), a refresh indicator for programmatic refreshes over a populated list, an inline error state with Retry, and a dedicated invalid-API-key screen with Retry.
- The list's sort selection now persists across launches (stored in `UserDefaults`), and a comment-count sort option joins votes/newest/oldest.
- Mailing-list sub-toggles (operational / marketing emails) are now offered when voting from the feedback list, matching the detail screen.
- Accessibility hints and labels on the vote dialog: the email field carries an accessible name, and the notify and mailing-list sub-toggles carry VoiceOver hints.

### Changed

- `SwiftlyFeedbackError` now provides localized, user-presentable descriptions for its eight presentable cases (invalid response, bad request, unauthorized, not found, conflict, server error, network error, decoding error) instead of raw enum text.
- Vote and comment counts shown by the SDK's views are pluralized via the String Catalog (correct singular/plural in every shipped locale).
- **Behavioural note for hosts:** `Feedback`'s `==` and `hash(into:)` now compare full content (title, description, status, votes, …), not just `id`. Code that relied on identity-only equality — e.g. treating a re-fetched, edited item as "equal" — will now see content changes as inequality.

- One `VoteDialogView` replaces the two per-surface vote-dialog copies (list and detail); both surfaces now share the same dialog body and presentation.
- **Breaking:** `StatusColors` and `CategoryColors` properties (and `color(for:)`) now expose `ThemeColor` instead of `Color`, so status and category badges adapt to light/dark mode. Migration: wrap literals — `= .gray` becomes `= .color(.gray)` — or adopt `.adaptive(light:dark:)` for per-scheme values.
- **Breaking:** `SegmentedControlConfiguration` is renamed `StatusFilterConfiguration`, and `config.buttons.segmentedControl` is renamed `config.buttons.statusFilter`. It gates the status Picker in the list's toolbar filter menu — there is no segmented control.
- `ThemeColor` now conforms to `Equatable` and `Hashable`.
- Feedback detail: the navigation bar now shows the feedback item's own title (instead of a generic "Details"), with a Share toolbar action and, on macOS, a comments Refresh button (⌘R). Comments support pull-to-refresh, load as redacted placeholder rows instead of a spinner, show a dedicated empty state once the first fetch completes, and the section header uses a localized plural comment count.
- Submit feedback: all form fields are disabled while a submission is in flight, and while the form is invalid a caption under the description field (iOS) / form grid (macOS) states which required field is missing — the same reason is read by VoiceOver on the Submit button's hint.

### Removed

- **Breaking:** `Strings.feedbackDetailTitle` and `Strings.commentsTitle` (and their catalog keys) — the detail screen now titles itself with the feedback item's title and renders its comments header via the pluralized `Strings.commentsCount(_:)`.
- **Breaking:** `theme.secondaryColor` and `theme.tertiaryColor` (never read by any view).
- **Breaking:** `AddButtonConfiguration.bottomPadding` (never read by any view).
- The unused row struct in the row-view file; the card-based row is the one the list renders.
- Two callerless HTTP verbs on the internal client: the PATCH verb and the body-less DELETE overload.

## [1.1.1] - 2026-04-24

### Fixed

- Fully-qualified all `@Environment(\.…)` uses in SwiftUI views as `@SwiftUI.Environment(\.…)` to avoid an ambiguity introduced by Swift 6.2 / Xcode 26 where the SDK's own `Environment` type could shadow `SwiftUI.Environment`. Consumers can now build against Xcode 26 without `ambiguous use of 'Environment'` errors.

## [1.1.0] - 2026-04-15

### Added

- CONTRIBUTING.md with contribution guidelines
- SECURITY.md with vulnerability reporting policy
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- Package.swift metadata comment block

### Changed

- Standardized documentation across all FeedbackKit SDKs

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

[1.1.1]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.1.1
[1.1.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.1.0
[1.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.0.0
