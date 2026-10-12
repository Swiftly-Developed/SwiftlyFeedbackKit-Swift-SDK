# Changelog

All notable changes to FeedbackKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - unreleased

Documented from `dev` on 12 October 2026. Not tagged. The public package repository [SwiftlyFeedbackKit-Swift-SDK](https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-Swift-SDK) still serves **1.1.1** (24 April 2026) on `main`. There is no `1.0.1` tag and no `1.1.2` tag. The query-item fix described under 1.1.2 below is in this tree and was not published on its own. The notes under this heading were first drafted on 2026-08-25 and updated for the Swift 6 language mode, the settings rename, and the removed `Strings` enum.

> ⚠️ **Release precondition — read before upgrading.** This version's headline feature is the
> metrics read API, and the metrics endpoints are **not yet deployed to every environment**.
> Measured 2026-08-25: the development API serves them; the **testflight and production APIs
> answer `404`** to `/api/v1/metrics/summary` while their `/health` answers `200`, so the routes
> are genuinely absent rather than the service being down. Until that deploy lands, a metrics call
> against production fails. Every other change in this release is unaffected.

> 🔎 **Last chance to rename one public symbol.** `MetricMeasure.isAvailableOnAPIKey` is public,
> and publishing `2.0.0` freezes its spelling until the next major. The package is genuinely
> inconsistent about this acronym: `EnvironmentAPIKeys`, `baseURL` and `itemID` use the
> all-caps form (which is also what Swift's API Design Guidelines prescribe for a non-leading
> acronym), while the public error cases `invalidApiKey` and `hasInvalidApiKey` use `ApiKey`.
> Whichever way it is settled, it should be settled **before** the tag is cut, not after.
> This release does **not** rename it.

Major version bump per the SemVer policy in `SwiftlyFeedbackKit/CLAUDE.md`: this release removes and renames public API. The break list is [MIGRATION.md](MIGRATION.md). The package compiles in Swift 6 language mode.

### Added

- **Metrics.** Four read-only operations on the `SwiftlyFeedback` facade — `metricsSummary`, `metricsTimeseries`, `metricsBreakdown` and `metricsEvents` — reporting aggregate usage for the project the API key identifies, plus the models behind them (`MetricsMeta`, `MetricSummary`, `MetricSeries`, `MetricSeriesPoint`, `MetricBreakdown`, `MetricBreakdownItem`, `MetricEventList`) and the typed vocabularies `MetricMeasure`, `MetricGranularity`, `MetricDimension`, `MetricEventScope`, `PredefinedEventName` and `MetricsErrorCode`. Measure values are read through an optional-returning subscript (`summary[.feedbackCount]`) because the server's `values` map is sparse by design — a breakdown's overflow row omits `uniqueEventUsers` entirely. No UI ships with this: the four calls are data, and presentation is the host app's. See the README's Metrics section for the empty-bucket shape, the Free-tier `200`, and the incremental-sync pattern.
- **String catalog plugin.** `GenerateStringCatalogSymbols` generates the package's localized symbols at build time. Xcode asks the host to trust the plugin once. A non-interactive `xcodebuild` passes `-skipPackagePluginValidation`.
- Reader-side on-device translation of feedback content (iOS and macOS): titles, descriptions, rejection reasons, and comments written in another language are translated toward the device locale, with a per-item "Translated from ⟨language⟩" affordance and Show original / Show translation toggle on list cards, the detail header, and comment rows. Original text always paints first; translations never block rendering; failures fall back silently to the original. The affordance is absent — never disabled — on visionOS and for unsupported language pairs. Controlled by the `translationEnabled` configuration knob (default on), backed by internal infrastructure (source-language detection, per-source batching, in-memory caching — never persisted).
- Feedback list search: a search field with free-text matching over titles and descriptions plus suggested status and category tokens, and a dedicated "no results" empty state with a clear-search action.
- Feedback list loading and error states: a skeleton placeholder during initial loads (with a 150 ms no-flash grace), a refresh indicator for programmatic refreshes over a populated list, an inline error state with Retry, and a dedicated invalid-API-key screen with Retry.
- The list's sort selection now persists across launches (stored in `UserDefaults`), and a comment-count sort option joins votes/newest/oldest.
- Mailing-list sub-toggles (operational / marketing emails) are now offered when voting from the feedback list, matching the detail screen.
- Accessibility hints and labels on the vote dialog: the email field carries an accessible name, and the notify and mailing-list sub-toggles carry VoiceOver hints.

### Fixed

- **`updateUser(customID:)` now changes the id on the live client.** The custom id was written to the Keychain, then registration kept sending the id captured at `configure`. Later feedback, votes, comments, and events stayed on the anonymous id until the next launch. A custom id set while configuration is still resolving is applied when the client is published, and an iCloud lookup that is in flight no longer overwrites a custom id stored during that wait. The iCloud lookup gives up after 3 seconds so an offline CloudKit call cannot leave `current` nil. Present since `1.0.0`.
- **Logs no longer include the API key or personal data.** Request and response bodies (email, user id, MRR) were written to OSLog, and a decode failure logged the payload. Logs now carry the method, path, and status only. Present since `1.0.0`.
- **Offline and timeout failures surface as `SwiftlyFeedbackError.networkError`.** Transport errors were rethrown as `URLError`, so the documented `networkError` case never matched. Each request now times out after 30 seconds. The client does not retry: a retried submit or vote would be sent twice. Present since `1.0.0`.
- **An unknown feedback status no longer blanks the list.** One undecodable row used to fail the whole `[Feedback]` decode. That row is dropped and the rows this build understands, including `testflight`, are returned. A fetch of that single item still throws `decodingError`. Dates accept whole-second ISO-8601 and the same instant with fractional seconds. A payload that omits fields added after `1.0.0` (`is_hidden_over_limit`, roadmap, sync state) still decodes. The list failure was present since `1.0.0`. The server's encoder does not currently emit fractional seconds; accepting them keeps a future encoder from dropping those rows.
- **DocC samples and the README samples match the API.** The configuration overview called the property `configurationuration`. The vote sample read `voteCount` on an optional `VoteResult`. The error-handling sample's typed `catch` was not exhaustive under Swift 6.

- **The SDK's feedback filters never reached the server.** `getFeedback(status:)` and `getFeedback(category:)` built a query string and appended it to the request path, and `URL.appendingPathComponent` percent-escapes `?` to `%3F` — so the whole thing became one path segment, the request named a route that does not exist, the server answered **404**, and the SDK surfaced `SwiftlyFeedbackError.notFound`. Every non-`nil` filter selection was affected, including the status filter in `FeedbackListView`'s own toolbar; the unfiltered default appended nothing and worked, which is why this survived. Query building now goes through `URLComponents`/`URLQueryItem` with `+` escaped to `%2B` (the server's form parser rewrites a literal `+` to a space before decoding), so event names and filter values containing `&`, `#`, `+` or `%` now arrive intact. Query-less requests are byte-identical to before. The same fix was drafted as 1.1.2 and was never tagged, so it ships in 2.0.0. The entry below is that unpublished note.

### Changed

- **Swift 6 language mode.** `Package.swift` sets `swiftLanguageModes: [.v6]`. Deployment targets are unchanged (iOS 26, macOS 26, visionOS 26).
- **Configuration is main-actor isolated.** `SwiftlyFeedback.configuration`, `SwiftlyFeedback.appearance`, and `SwiftlyFeedback.current` replace the `nonisolated(unsafe)` `config`, `theme`, and `shared` storage. The old names still compile as deprecated shims that forward to the new properties, so an existing `SwiftlyFeedback.config.allowUndoVote = false` keeps working and warns. Call the new properties from the main actor. See [MIGRATION.md](MIGRATION.md).
- Documented metrics windows are Free 30 days, Pro 90 days and Team 365 days. The SDK still reads `retentionWindowDays` from the response; it does not hardcode them. A Pro request wider than 90 days comes back clamped at `200`, the same way a Free request wider than 30 days already did.
- **Breaking (behavioural):** three arms of the HTTP-status → `SwiftlyFeedbackError` map move, and a host app that switches exhaustively will see the difference. A **403** carrying the shared middleware's body — a role, access or suspension refusal — was `serverError(statusCode: 403)` and is now `forbidden(message:)`. A **429** was `serverError(statusCode: 429)` and is now `rateLimited(message:)`, so a host app can back off instead of treating a rate limit as a server fault. A **403** carrying the metrics envelope's `METRICS_MEASURE_REQUIRES_BEARER` code is now `measureNotAvailable(measure:message:)`, naming the measure the server refused. The **402** arm is deliberately unmoved: the new `tierUpgradeRequired(code:message:)` is keyed on the envelope's `error.code`, not on the status, so every 402 the feedback, project and member caps raise keeps `feedbackLimitReached(message:)`.
- The error decoder now handles **both** body shapes the server produces — the metrics envelope, where `error` is an object carrying `code`/`message`/`field`, and the shared middleware's, where `error` is a boolean alongside `reason` — branching on which decode succeeded rather than on the status code, because 403 arrives in both. Message extraction keeps its shipped precedence (`reason` before `message`, with a non-JSON body passing through raw); the envelope's `error.message` is appended as a third source, never inserted ahead of the two.
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

- **Breaking:** the public `Strings` enum. Every `Strings.*` member from 1.1.1 is gone, including `Strings.feedbackDetailTitle` and `Strings.commentsTitle`. Hosts override copy through string catalog keys. The detail screen titles itself with the feedback item's title. The comments header is a pluralized catalog string inside the package.
- **Breaking:** `theme.secondaryColor` and `theme.tertiaryColor` (never read by any view).
- **Breaking:** `AddButtonConfiguration.bottomPadding` (never read by any view).
- The unused row struct in the row-view file; the card-based row is the one the list renders.
- Two callerless HTTP verbs on the internal client: the PATCH verb and the body-less DELETE overload.

## [1.1.2] - 2026-08-25

### Fixed

- **The feedback list's status and category filters no longer fail.** `getFeedback(status:category:)` concatenated its query into the request *path*, and the networking client built URLs with `appendingPathComponent`, which treats its argument as a single path component and percent-escapes the `?`. `feedbacks?status=pending` therefore went out as the path segment `feedbacks%3Fstatus=pending` and the server answered **404**, surfacing as an error screen whenever a user picked any status other than "All". The status filter is on by default, so this affected every host app embedding `FeedbackListView`. The query is now carried to the client as `[URLQueryItem]` and attached with `URLComponents`. Not a regression — present in every release since `1.0.0`. No API change.

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
