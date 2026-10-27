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
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    /// macOS draws the vote control beside the link, never in its label: a button inside a
    /// macOS list's navigation-link label never receives the click.
    #if os(macOS)
    static let drawsVoteOutsideLink = true
    #else
    static let drawsVoteOutsideLink = false
    #endif

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
                    translationTargetName: projection.targetName,
                    showsVoteControl: !Self.drawsVoteOutsideLink
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
                    translationTargetName: projection.targetName,
                    showsVoteControl: !Self.drawsVoteOutsideLink
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

        HStack(alignment: .center, spacing: 0) {
            #if os(macOS)
            if style == .classic, config.showVoteCount {
                // The Classic card's leading column, drawn here so the click reaches it.
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: { Task { await viewModel.toggleVote(for: feedback) } }
                )
                .accessibilityIdentifier("fbk-feedback-vote-button-\(feedback.id.uuidString)")
                .padding(.trailing, 8)
            }
            #endif
            Group {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            #if os(macOS)
            // One trailing column: the actions glyph sits top-trailing inside the card,
            // on the same trailing edge as the vote capsule below it.
            .overlay(alignment: .topTrailing) { moderationMenu }
            .overlay(alignment: .bottomTrailing) {
                if style == .showcase {
                    // Outside the link, like the Classic column above.
                    FeedbackShowcaseVoteCapsule(
                        feedbackID: feedback.id,
                        voteCount: feedback.voteCount,
                        presentation: presentation,
                        tint: SwiftlyFeedback.appearance.primaryColor.resolve(for: colorScheme),
                        action: { Task { await viewModel.toggleVote(for: feedback) } }
                    )
                    .padding(.bottom, 6)
                }
            }
            #endif

            #if !os(macOS)
            moderationMenu
            #endif
        }
    }

    @ViewBuilder
    private var moderationMenu: some View {
            if ModerationMenuVisibility.isVisible(
                authorUserId: feedback.userId,
                currentUserId: UserIdentifier.getCurrentUserId()
            ) {
                ContentModerationMenu(
                    onReport: { reason in
                        Task { await viewModel.report(feedback, reason: reason) }
                    },
                    onBlock: {
                        Task { await viewModel.blockAuthor(of: feedback) }
                    }
                )
                #if os(macOS)
                .padding(.top, 4)
                #endif
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
