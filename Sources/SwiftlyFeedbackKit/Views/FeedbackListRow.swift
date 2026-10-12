import SwiftUI

/// One feedback row in the system list. The row is a `NavigationLink`, so the
/// disclosure, shape, and RTL come from the list. Vote and translation stay
/// real controls, and the same actions are on the link for when the list
/// presents the row as a single VoiceOver element.
struct FeedbackListRow: View {
    @Bindable var viewModel: FeedbackListViewModel
    let feedback: Feedback
    let translator: FeedbackTranslator
    /// The reader's resolved target, handed down rather than re-derived.
    let target: Locale.Language

    @SwiftUI.Environment(\.locale) private var locale

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    var body: some View {
        let projection = translationProjection
        let isShowingOriginal = viewModel.showOriginalIDs.contains(feedback.id)
        let link = NavigationLink(value: feedback) {
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
        .accessibilityHint(String(localized: .accessibilityViewDetails))

        let translationActionName: String? = projection.sourceName == nil
            ? nil
            : String(localized: isShowingOriginal ? .translationShowTranslation : .translationShowOriginal)
        let voteActionName: String? = {
            guard config.showVoteCount, feedback.status.canVote else { return nil }
            if feedback.hasVoted, !config.allowUndoVote { return nil }
            return String(localized: feedback.hasVoted ? .buttonVoted : .buttonVote)
        }()

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
