import SwiftUI

struct VoteButton: View {
    let voteCount: Int
    let hasVoted: Bool
    let status: FeedbackStatus
    let action: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.redactionReasons) private var redactionReasons

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    /// The host tint, which is the system accent unless the host set one. The count is `.primary`.
    private var controlTint: Color {
        theme.primaryColor.resolve(for: colorScheme)
    }

    private var chrome: VoteButtonChrome {
        VoteButtonChrome.resolve(
            isPlaceholder: redactionReasons.contains(.placeholder),
            hasVoted: hasVoted
        )
    }

    private var isDisabled: Bool {
        !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    /// Closed keeps its "Voting is closed" hint on this disabled control; every votable cell
    /// takes the shared resolver's hint, so a locked vote never offers to remove itself.
    private var accessibilityHintText: String {
        guard status.canVote else { return String(localized: .accessibilityVotingClosed) }
        let presentation = VotePresentation.resolve(
            showVoteCount: true,
            isPlaceholder: false,
            canVote: true,
            hasVoted: hasVoted,
            allowUndoVote: config.allowUndoVote
        )
        return presentation.accessibilityHint?.localizedText ?? ""
    }

    var body: some View {
        Button(action: action) {
            if chrome.fill == .placeholder {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 44, height: 52)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.footnote.bold())
                        .foregroundStyle(controlTint)
                        .accessibilityHidden(true)
                    // A system label, not a SwiftUI `Text` that sets both a font and a
                    // foreground style. That combination is what the Dynamic Type audit
                    // calls only partly supported once this control shares a card row.
                    SystemLabel(
                        text: voteCount.formatted(.number),
                        textStyle: .body,
                        showsBackground: false
                    )
                }
                .frame(width: 44, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(chrome.fill == .tintWash ? controlTint.opacity(0.18) : Color.clear)
                }
                .overlay {
                    if chrome.showsStroke {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(controlTint, lineWidth: 1)
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        .tint(controlTint)
        .disabled(isDisabled)
        .accessibilityLabel(Text(voteCount, format: .number))
        .accessibilityInputLabels([
            String(localized: hasVoted ? .buttonVoted : .buttonVote)
        ])
        .accessibilityValue(hasVoted ? String(localized: .accessibilityVoted) : String(localized: .accessibilityNotVoted))
        .accessibilityHint(accessibilityHintText)
    }
}
