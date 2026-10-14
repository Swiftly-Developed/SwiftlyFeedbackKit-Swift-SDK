import SwiftUI

struct FeedbackCardView: View {
    let feedback: Feedback
    let onVote: () -> Void
    /// Translated projections, `nil` when no translation is cached (defaults keep
    /// existing call sites source-compatible). Original text is always the first
    /// paint — these fill in only when the translation cache does.
    var translatedTitle: String? = nil
    var translatedDescription: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil
    /// Localized name of the reader's chosen target language; `nil` when that target IS
    /// the device language, which keeps the existing one-argument copy.
    var translationTargetName: String? = nil

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    /// The title as displayed: the translated projection when present and not
    /// toggled back to the original.
    private var displayedTitle: String {
        if !isShowingOriginal, let translatedTitle { return translatedTitle }
        return feedback.title
    }

    /// The description as displayed; same projection rule as ``displayedTitle``.
    private var displayedDescription: String {
        if !isShowingOriginal, let translatedDescription { return translatedDescription }
        return feedback.description
    }

    var body: some View {
        HStack(alignment: .center) {
            if config.showVoteCount {
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: onVote
                )
            }

            VStack(alignment: .leading) {
                Text(displayedTitle)
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                Text(displayedDescription)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let translationSourceName, let onToggleTranslation {
                    TranslationAffordanceView(
                        sourceLanguageName: translationSourceName,
                        targetLanguageName: translationTargetName,
                        isShowingOriginal: isShowingOriginal,
                        onToggle: onToggleTranslation
                    )
                }

                FeedbackRowMetadataView(feedback: feedback)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

