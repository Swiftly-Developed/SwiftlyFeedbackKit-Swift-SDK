import SwiftUI

/// One feedback row in the system list, in either list style. The row is a
/// `NavigationLink`, so the disclosure, shape, and RTL come from the list. Vote and
/// translation stay real controls, and the same actions are on the link for when the
/// list presents the row as a single VoiceOver element.
struct FeedbackListRow: View {
    @Bindable var viewModel: FeedbackListViewModel
    let feedback: Feedback
    let translator: FeedbackTranslator
    /// The reader's resolved target, handed down rather than re-derived.
    let target: Locale.Language
    let style: FeedbackListStyle

    @SwiftUI.Environment(\.locale) private var locale

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    var body: some View {
        let projection = translationProjection
        let isShowingOriginal = viewModel.showOriginalIDs.contains(feedback.id)
        let link = NavigationLink(value: feedback) {
            switch style {
            case .showcase:
                FeedbackShowcaseCard(
                    feedback: feedback,
                    onVote: { Task { await viewModel.toggleVote(for: feedback) } },
                    translatedTitle: projection.title,
                    translatedDescription: projection.description,
                    translationSourceName: projection.sourceName,
                    isShowingOriginal: isShowingOriginal,
                    onToggleTranslation: { viewModel.toggleShowOriginal(feedback.id) },
                    translationTargetName: projection.targetName
                )
            case .classic:
                FeedbackCardView(
                    feedback: feedback,
                    onVote: { Task { await viewModel.toggleVote(for: feedback) } },
                    translatedTitle: projection.title,
                    translatedDescription: projection.description,
                    translationSourceName: projection.sourceName,
                    isShowingOriginal: isShowingOriginal,
                    onToggleTranslation: { viewModel.toggleShowOriginal(feedback.id) },
                    translationTargetName: projection.targetName
                )
            }
        }
        .accessibilityHint(String(localized: .accessibilityViewDetails))
        .accessibilityIdentifier(
            style == .showcase
                ? "fbk-feedback-card-\(feedback.id.uuidString)"
                : "fbk-feedback-row-\(feedback.id.uuidString)"
        )
        #if os(macOS)
        // Plain lists were drawing a separator under some rows only. Every row
        // uses the same full-width rule. Showcase rows are one per section and need none.
        .listRowSeparator(style == .classic ? .visible : .hidden)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        #endif

        let translationActionName: String? = projection.sourceName == nil
            ? nil
            : String(localized: isShowingOriginal ? .translationShowTranslation : .translationShowOriginal)
        let presentation = VotePresentation.resolve(for: feedback, isPlaceholder: false, configuration: config)
        let voteActionName: String? = presentation.isEnabled
            ? String(localized: presentation.isProminent ? .buttonVoted : .buttonVote)
            : nil

        switch (translationActionName, voteActionName) {
        case let (translation?, vote?):
            link
                .accessibilityAction(named: translation) {
                    viewModel.toggleShowOriginal(feedback.id)
                }
                .accessibilityAction(named: vote) {
                    Task { await viewModel.toggleVote(for: feedback) }
                }
        case let (translation?, nil):
            link.accessibilityAction(named: translation) {
                viewModel.toggleShowOriginal(feedback.id)
            }
        case let (nil, vote?):
            link.accessibilityAction(named: vote) {
                Task { await viewModel.toggleVote(for: feedback) }
            }
        case (nil, nil):
            link
        }
    }

    /// Cached projections plus the localized source- and target-language names.
    /// All `nil` (affordance absent, original text stands) until the cache fills,
    /// and when the source language has no localized display name.
    ///
    /// `targetName` is `nil` whenever the target is the device language, which
    /// selects the one-argument affordance copy.
    private var translationProjection: (
        title: String?, description: String?, sourceName: String?, targetName: String?
    ) {
        let title = translator.translation(
            for: feedback.id, field: .title, target: target, sourceText: feedback.title
        )
        let description = translator.translation(
            for: feedback.id, field: .description, target: target, sourceText: feedback.description
        )
        guard title != nil || description != nil else { return (nil, nil, nil, nil) }
        let source = SourceLanguageDetector.detect(feedback.description)
            ?? SourceLanguageDetector.detect(feedback.title)
        guard let sourceName = source?.localizedDisplayName(in: locale) else {
            return (nil, nil, nil, nil)
        }
        let targetName: String? = target.isSameLanguage(as: locale.language)
            ? nil
            : target.localizedTargetName(in: locale)
        return (title, description, sourceName, targetName)
    }
}
