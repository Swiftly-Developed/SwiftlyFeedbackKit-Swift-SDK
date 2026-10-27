import SwiftUI

/// A content-first card: status eyebrow, the title, the whole description (never
/// truncated), the translation affordance, and a footer with facts and the vote control.
///
/// No background of its own: the grouped list section is the card.
struct FeedbackShowcaseCard: View {
    let feedback: Feedback
    let onVote: () -> Void
    /// Translated projections, `nil` when no translation is cached. Original text is always
    /// the first paint.
    var translatedTitle: String? = nil
    var translatedDescription: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil
    /// Localized name of the reader's chosen target; `nil` when it is the device language.
    var translationTargetName: String? = nil
    /// `false` when the caller draws the vote capsule itself, outside a navigation link
    /// whose label would swallow the click (macOS lists).
    var showsVoteControl: Bool = true

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.redactionReasons) private var redactionReasons
    @ScaledMetric(relativeTo: .title3) private var eyebrowGap = 8
    @ScaledMetric(relativeTo: .subheadline) private var descriptionGap = 4
    @ScaledMetric(relativeTo: .footnote) private var footerGap = 14
    @ScaledMetric(relativeTo: .body) private var verticalPadding = 6

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    private var displayedTitle: String {
        if !isShowingOriginal, let translatedTitle { return translatedTitle }
        return feedback.title
    }

    private var displayedDescription: String {
        if !isShowingOriginal, let translatedDescription { return translatedDescription }
        return feedback.description
    }

    var body: some View {
        let resolved = VotePresentation.resolve(
            for: feedback,
            isPlaceholder: redactionReasons.contains(.placeholder),
            configuration: config
        )
        let presentation = showsVoteControl ? resolved : .hidden
        let category = config.showCategoryBadge ? feedback.category : nil
        let commentCount = config.showCommentSection && feedback.commentCount > 0 ? feedback.commentCount : nil
        let hasFooter = category != nil || commentCount != nil || presentation != .hidden

        VStack(alignment: .leading, spacing: 0) {
            if config.showStatusBadge {
                FeedbackStatusEyebrowView(status: feedback.status)
                    .padding(.bottom, eyebrowGap)
            }

            Text(displayedTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Text(displayedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .padding(.top, descriptionGap)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    targetLanguageName: translationTargetName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
                .padding(.top, descriptionGap)
            }

            if hasFooter {
                FeedbackShowcaseFooter(
                    feedbackID: feedback.id,
                    category: category,
                    commentCount: commentCount,
                    voteCount: feedback.voteCount,
                    presentation: presentation,
                    tint: SwiftlyFeedback.appearance.primaryColor.resolve(for: colorScheme),
                    onVote: onVote
                )
                .padding(.top, footerGap)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The caller's capsule sits bottom-trailing; keep a footer's worth of room for it
        // when there are no facts to share the line with.
        .padding(.bottom, !showsVoteControl && resolved != .hidden && category == nil && commentCount == nil ? footerGap + 24 : 0)
        .padding(.vertical, verticalPadding)
    }
}
