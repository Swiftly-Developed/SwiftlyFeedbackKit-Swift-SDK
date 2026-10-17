# Migrating to SwiftlyFeedbackKit 1.3.0

This note is the source break list from 1.1.1 to 1.3.0. Two releases were tagged on 14 October 2026 as `2.0.0` and `3.0.0`. On 17 October 2026 they were renumbered `1.2.0` and `1.3.0`, and the `2.0.0` and `3.0.0` tags were deleted. Both contain source-breaking changes despite their minor version numbers. A `Package.resolved` that pins `2.0.0` or `3.0.0` must be re-resolved.

Sections marked **(1.2.0)** already apply on the `1.2.0` tag. Every other section first applies in 1.3.0, so a host on `1.2.0` only needs the unmarked sections.

## Swift 6 language mode

`Package.swift` sets `swiftLanguageModes: [.v6]`. The `1.1.1` and `1.2.0` tags set `[.v5]`.

Deployment targets are unchanged: iOS 26, macOS 26, and visionOS 26. The package does not declare watchOS or tvOS.

A host that compiles in Swift 5 language mode can still import the package. The package itself is type-checked in Swift 6 mode, so the public surface is main-actor isolated where the declarations below say so.

## Settings, theme, and the configured client

1.3.0 replaces the three `nonisolated(unsafe)` stores from 1.1.1 and 1.2.0 with main-actor properties. Read and write them from your `App` initializer, a SwiftUI view, or any `@MainActor` type.

| 1.1.1 and 1.2.0 | 1.3.0 |
| --- | --- |
| `SwiftlyFeedback.config` | `SwiftlyFeedback.configuration` |
| `SwiftlyFeedback.theme` | `SwiftlyFeedback.appearance` |
| `SwiftlyFeedback.shared` | `SwiftlyFeedback.current` |

The old names still compile. Each one is a deprecated shim that forwards to the property in the right-hand column, and the compiler warns at each use.

```swift
// Before
SwiftlyFeedback.config.allowUndoVote = false
SwiftlyFeedback.config.loggingEnabled = false

// After
SwiftlyFeedback.configuration.allowUndoVote = false
SwiftlyFeedback.configuration.loggingEnabled = false
```

`current` stays `nil` until `configure` finishes resolving a user id.

```swift
// Before
let feedback = try await SwiftlyFeedback.shared?.getFeedback()

// After
let feedback = try await SwiftlyFeedback.current?.getFeedback()
```

`configure(with:)`, `configure(environment:key:)`, and `configureAuto(keys:)` are unchanged. `configureAuto(with:)` was already deprecated in favor of `configureAuto(keys:)`. `updateUser(email:)` remains a deprecated no-op; set email on submit or on the vote.

`configureAuto(keys:)` sends DEBUG builds to the development API (`https://api.dev.getfeedbackkit.com/api/v1`). Localhost is only `configure(environment: .local, key:)`.

## Theme colors (1.2.0)

`StatusColors` and `CategoryColors`, including `color(for:)`, now expose `ThemeColor` instead of `Color`. `primaryColor` was already `ThemeColor` in 1.1.1.

```swift
// Before
SwiftlyFeedback.theme.primaryColor = .color(.blue)
SwiftlyFeedback.theme.statusColors.pending = .gray

// After
SwiftlyFeedback.appearance.primaryColor = .color(.blue)
SwiftlyFeedback.appearance.statusColors.pending = .color(.gray)
SwiftlyFeedback.appearance.primaryColor = .adaptive(light: .blue, dark: .cyan)
```

A bare `.gray` assignment on a status or category color no longer type-checks. On the `1.2.0` tag, write the same values through `SwiftlyFeedback.theme`: `appearance` arrives in 1.3.0, where `theme` still compiles and forwards to it.

There is no `accentColor` property. Buttons and highlights read `primaryColor`. `.default` resolves to the system accent color.

## String catalog symbols

The public `Strings` enum is removed in 1.3.0. `1.2.0` already dropped `Strings.feedbackDetailTitle` and `Strings.commentsTitle`; 1.3.0 removes every other `Strings.*` member. Host apps override copy by adding the same keys to their own `Localizable.xcstrings`. They do not call a `Strings` type.

The package generates its own symbols with the `GenerateStringCatalogSymbols` build-tool plugin. Xcode asks you to trust that plugin once. A non-interactive `xcodebuild` passes `-skipPackagePluginValidation`.

The detail screen titles itself with the feedback item's title. The comments header is a pluralized catalog string inside the package.

## Other removed symbols (1.2.0)

- `appearance.secondaryColor` (was `theme.secondaryColor`)
- `appearance.tertiaryColor` (was `theme.tertiaryColor`)
- `AddButtonConfiguration.bottomPadding`

## Status filter configuration (1.2.0)

`SegmentedControlConfiguration` is now `StatusFilterConfiguration`. `configuration.buttons.segmentedControl` is now `configuration.buttons.statusFilter`. The value gates the status picker in the list toolbar. There is no segmented control. The deprecated `config` shim forwards the same object, so `config.buttons.statusFilter` is the same property.

## HTTP errors

Three arms of the status-to-`SwiftlyFeedbackError` map moved. An exhaustive `switch` needs new cases.

| Status | Was | Is |
| --- | --- | --- |
| 403 with the shared middleware body (role, access, or suspension) | `serverError(statusCode: 403)` | `forbidden(message:)` |
| 429 | `serverError(statusCode: 429)` | `rateLimited(message:)` |
| 403 with code `METRICS_MEASURE_REQUIRES_BEARER` | `serverError` | `measureNotAvailable(measure:message:)` |

A 402 whose envelope code is `METRICS_CUSTOM_EVENTS_REQUIRE_PRO` is `tierUpgradeRequired(code:message:)`. Any other 402 is still `feedbackLimitReached(message:)`. The Free-plan feedback cap does not use that path: the row saves with HTTP 2xx and `isHiddenOverLimit == true`, and list reads omit it. See Plan limits in the README.

The decoder accepts both body shapes: the metrics envelope (`error` is an object with `code`, `message`, and `field`) and the middleware body (`error` is a boolean next to `reason`).

## Feedback equality (1.2.0)

`Feedback.==` and `hash(into:)` compare the full value (title, description, status, votes, and the rest), not only `id`. A re-fetched item whose content changed is no longer equal to the previous value.

## Metrics reads

These are new, not a rename. On the configured client:

- `metricsSummary(measures:days:)`
- `metricsTimeseries(measures:granularity:days:)`
- `metricsBreakdown(measures:dimension:days:)`
- `metricsEvents(...)`

The API key identifies the project. Pass `days` or a `dateFrom`/`dateTo` pair, not both. A window wider than the plan allows returns HTTP 200 with `meta.retentionClamped`. Read `meta.retentionWindowDays` from the response. The windows are Free 30 days, Pro 90 days, and Team 365 days. The SDK does not hardcode them.

Measure values are sparse. Read them with the optional subscript (`summary[.feedbackCount]`). A breakdown overflow row omits `uniqueEventUsers`.

## List filters

`getFeedback(status:category:)` sends filters as query items. Tags before 1.3.0, including `1.2.0`, append the query to the path, so `URL.appendingPathComponent` escapes `?` and the server answers 404. Hosts that worked around that 404 can drop the workaround once they are on 1.3.0.

## 1.3.0: the feedback list looks different

`FeedbackListView` draws the Showcase list by default: one card per request with a status line, the whole description, and a vote capsule. To keep the previous look, set the list style to Classic before the list appears:

```swift
SwiftlyFeedback.configuration.listStyle = .classic
```

Nothing else needs a change. `FeedbackListView()` takes the same arguments. Other changes a host may notice:

- The status and category filters live in the toolbar's Sort & Filter menu and filter the loaded list on the device. `configuration.buttons.categoryFilter.display = false` hides the Category picker.
- In Showcase, a completed or rejected request shows its vote count as text, and the category is secondary text. `appearance.categoryColors` still colours Classic rows and the detail screen.
- `FeedbackCategory.improvement.iconName` is `slider.horizontal.3`.
- `configuration.expandDescriptionInList` is deprecated and has no effect. Delete the line.
