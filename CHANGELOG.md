# Changelog

All notable changes to FeedbackKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-10-14

The feedback list's Showcase look, from spec [`FEEDBACK01`](../docs/specs/FEEDBACK01.md). Major version: the changes listed under "Also first shipped in 3.0.0" below break source compatibility with the `2.0.0` tag — Swift 6 language mode, main-actor `config` / `theme` / `shared`, new `SwiftlyFeedbackError` cases, and the removal of the public `Strings` enum. [MIGRATION.md](MIGRATION.md) covers the upgrade. The Showcase list itself is additive, and the one deprecated property keeps compiling.

### Added

- **`configuration.listStyle`** (`FeedbackListStyle`): `.showcase`, the default, draws each request as its own card with a status eyebrow, the whole description, a category and comment footer, and a vote capsule. `.classic` keeps the 2.0 list.
- **Sort & Filter menu.** The toolbar menu now holds Sort By, a Filter section with Status and Category pickers, the translation-target picker, and Clear Filters while filtered. While a filter is active the icon fills, the button takes the prominent style, and its accessibility value reads "Filtered by …".
- **"Filtered by … Clear" row** at the top of a filtered list, in both styles, and a "No Matching Requests" state with Clear Filters when the filters leave nothing.
- **`configuration.buttons.categoryFilter.display`** (default `true`) gates the Category picker, as `statusFilter` gates Status.
- 19 strings for the menu, the filter row, the filtered-empty state, and VoiceOver, in all eleven locales.

### Changed

- **Showcase is the default list.** Set `configuration.listStyle = .classic` to keep the previous look. The detail screen, the submit form, and the vote dialog are unchanged.
- **Status and category filters run on the device.** The list loads once and filters the loaded rows, so changing a filter no longer refetches. `getFeedback(status:category:)` still sends server-side filters for direct API callers.
- **Closed requests show their vote count as text** in the Showcase list, with "Voting is closed" read by VoiceOver, instead of a disabled button.
- In the Showcase list the category is plain text. `appearance.categoryColors` keeps colouring Classic rows and the detail screen.
- **The list draws with system colours and the host's colours as set.** `primaryColor` and the status colours are never altered. Supporting text (the description, the footer facts, a closed count, the "Filtered by" sentence) uses the system secondary style, and the vote capsule sits on a system fill. These adapt to light mode, dark mode and Increase Contrast on their own. The vote control's chevron on Classic rows and the detail screen uses the system accent again when `primaryColor` is `.default`, instead of a fixed blue.
- **The vote hint matches what a tap does.** When votes cannot be removed, a voted control is announced as "You've voted. Votes can't be removed" instead of offering to remove the vote. This applies to the list, the Classic row, and the detail screen.
- The Improvement category glyph is `slider.horizontal.3`, so it no longer looks like the vote arrow.

### Deprecated

- `configuration.expandDescriptionInList`. It has no effect: both list styles show the whole description. Removed in the next major release.

Also first shipped in 3.0.0 (drafted earlier under the untagged 1.1.2 and 2.0.0-unreleased headings, never tagged):

> The metrics endpoints are not on every server yet. Measured 2026-10-14: the development and testflight APIs serve `/api/v1/metrics/summary`, and the production API answers `404` while its `/health` answers `200`. Metrics calls against production fail until that server deploy lands.

#### Added

- **Metrics.** Four read-only operations on the `SwiftlyFeedback` facade — `metricsSummary`, `metricsTimeseries`, `metricsBreakdown` and `metricsEvents` — reporting aggregate usage for the project the API key identifies, plus the models behind them (`MetricsMeta`, `MetricSummary`, `MetricSeries`, `MetricSeriesPoint`, `MetricBreakdown`, `MetricBreakdownItem`, `MetricEventList`) and the typed vocabularies `MetricMeasure`, `MetricGranularity`, `MetricDimension`, `MetricEventScope`, `PredefinedEventName` and `MetricsErrorCode`. Measure values are read through an optional-returning subscript (`summary[.feedbackCount]`) because the server's `values` map is sparse by design — a breakdown's overflow row omits `uniqueEventUsers` entirely. No UI ships with this: the four calls are data, and presentation is the host app's. See the README's Metrics section for the empty-bucket shape, the Free-tier `200`, and the incremental-sync pattern.
- **String catalog plugin.** `GenerateStringCatalogSymbols` generates the package's localized symbols at build time. Xcode asks the host to trust the plugin once. A non-interactive `xcodebuild` passes `-skipPackagePluginValidation`.

#### Changed

- **Swift 6 language mode.** `Package.swift` sets `swiftLanguageModes: [.v6]`. Deployment targets are unchanged (iOS 26, macOS 26, visionOS 26).
- **Configuration is main-actor isolated.** `SwiftlyFeedback.configuration`, `SwiftlyFeedback.appearance`, and `SwiftlyFeedback.current` replace the `nonisolated(unsafe)` `config`, `theme`, and `shared` storage. The old names still compile as deprecated shims that forward to the new properties, so an existing `SwiftlyFeedback.config.allowUndoVote = false` keeps working and warns. Call the new properties from the main actor. See [MIGRATION.md](MIGRATION.md).
- Documented metrics windows are Free 30 days, Pro 90 days and Team 365 days. The SDK still reads `retentionWindowDays` from the response; it does not hardcode them. A Pro request wider than 90 days comes back clamped at `200`, the same way a Free request wider than 30 days already did.
- **Breaking (behavioural):** three arms of the HTTP-status → `SwiftlyFeedbackError` map move, and a host app that switches exhaustively will see the difference. A **403** carrying the shared middleware's body — a role, access or suspension refusal — was `serverError(statusCode: 403)` and is now `forbidden(message:)`. A **429** was `serverError(statusCode: 429)` and is now `rateLimited(message:)`, so a host app can back off instead of treating a rate limit as a server fault. A **403** carrying the metrics envelope's `METRICS_MEASURE_REQUIRES_BEARER` code is now `measureNotAvailable(measure:message:)`, naming the measure the server refused. The **402** arm is deliberately unmoved: the new `tierUpgradeRequired(code:message:)` is keyed on the envelope's `error.code`, not on the status, so every 402 the feedback, project and member caps raise keeps `feedbackLimitReached(message:)`.
- The error decoder now handles **both** body shapes the server produces — the metrics envelope, where `error` is an object carrying `code`/`message`/`field`, and the shared middleware's, where `error` is a boolean alongside `reason` — branching on which decode succeeded rather than on the status code, because 403 arrives in both. Message extraction keeps its shipped precedence (`reason` before `message`, with a non-JSON body passing through raw); the envelope's `error.message` is appended as a third source, never inserted ahead of the two.

#### Fixed

- **`updateUser(customID:)` now changes the id on the live client.** The custom id was written to the Keychain, then registration kept sending the id captured at `configure`. Later feedback, votes, comments, and events stayed on the anonymous id until the next launch. A custom id set while configuration is still resolving is applied when the client is published, and an iCloud lookup that is in flight no longer overwrites a custom id stored during that wait. The iCloud lookup gives up after 3 seconds so an offline CloudKit call cannot leave `current` nil. Present since `1.0.0`.
- **Logs no longer include the API key or personal data.** Request and response bodies (email, user id, MRR) were written to OSLog, and a decode failure logged the payload. Logs now carry the method, path, and status only. Present since `1.0.0`.
- **Offline and timeout failures surface as `SwiftlyFeedbackError.networkError`.** Transport errors were rethrown as `URLError`, so the documented `networkError` case never matched. Each request now times out after 30 seconds. The client does not retry: a retried submit or vote would be sent twice. Present since `1.0.0`.
- **An unknown feedback status no longer blanks the list.** One undecodable row used to fail the whole `[Feedback]` decode. That row is dropped and the rows this build understands, including `testflight`, are returned. A fetch of that single item still throws `decodingError`. Dates accept whole-second ISO-8601 and the same instant with fractional seconds. A payload that omits fields added after `1.0.0` (`is_hidden_over_limit`, roadmap, sync state) still decodes. The list failure was present since `1.0.0`. The server's encoder does not currently emit fractional seconds; accepting them keeps a future encoder from dropping those rows.
- **DocC samples and the README samples match the API.** The configuration overview called the property `configurationuration`. The vote sample read `voteCount` on an optional `VoteResult`. The error-handling sample's typed `catch` was not exhaustive under Swift 6.
- **The SDK's feedback filters never reached the server.** `getFeedback(status:)` and `getFeedback(category:)` built a query string and appended it to the request path, and `URL.appendingPathComponent` percent-escapes `?` to `%3F` — so the whole thing became one path segment, the request named a route that does not exist, the server answered **404**, and the SDK surfaced `SwiftlyFeedbackError.notFound`. Every non-`nil` filter selection was affected, including the status filter in `FeedbackListView`'s own toolbar; the unfiltered default appended nothing and worked, which is why this survived. Query building now goes through `URLComponents`/`URLQueryItem` with `+` escaped to `%2B` (the server's form parser rewrites a literal `+` to a space before decoding), so event names and filter values containing `&`, `#`, `+` or `%` now arrive intact. Query-less requests are byte-identical to before.

#### Removed

- **Breaking:** the public `Strings` enum. Every `Strings.*` member from 1.1.1 is gone, including `Strings.feedbackDetailTitle` and `Strings.commentsTitle`. Hosts override copy through string catalog keys. The detail screen titles itself with the feedback item's title. The comments header is a pluralized catalog string inside the package.

## [2.0.0] - 2026-10-14

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
- Feedback detail now uses native list controls: an inset list with labeled status and category rows, a compact bordered vote button, a `ContentUnavailableView` empty state for comments, and a system comment field — replacing the custom cards, capsule badges and full-width vote box.
- Submit feedback: all form fields are disabled while a submission is in flight, and while the form is invalid a caption under the description field (iOS) / form grid (macOS) states which required field is missing — the same reason is read by VoiceOver on the Submit button's hint.

### Fixed

- The feedback list no longer redraws in a loop when it reads cached translations, which could keep the main thread busy and stop a feedback submission from being sent. View-path cache reads no longer publish an Observation change.

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

[3.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/3.0.0
[2.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/2.0.0
[1.1.1]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.1.1
[1.1.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.1.0
[1.0.0]: https://github.com/Swiftly-Developed/SwiftlyFeedbackKit/releases/tag/1.0.0
