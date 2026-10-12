import SwiftUI

struct VoteButton: View {
    let voteCount: Int
    let hasVoted: Bool
    let status: FeedbackStatus
    let action: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    /// The default accent misses 4.5:1. `.primary` is the system label color in both modes.
    /// A host-supplied theme color is left as they set it.
    private var controlTint: Color {
        if theme.primaryColor == .default {
            return .primary
        }
        return theme.primaryColor.resolve(for: colorScheme)
    }

    private var isDisabled: Bool {
        !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    private var accessibilityHintText: String {
        if !status.canVote {
            return String(localized: .accessibilityVotingClosed)
        } else if hasVoted {
            return String(localized: .accessibilityUnvoteHint)
        } else {
            return String(localized: .accessibilityVoteHint)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .accessibilityHidden(true)
                Text(voteCount, format: .number)
            }
            .font(.body)
            .frame(minWidth: 44, minHeight: 44)
        }
        // Prominent uses the tint as the fill and a contrasting label. `.primary`
        // is black in light mode and white in dark mode, so the system label flips
        // and both clear 4.5:1 at the largest text size. A bordered tint does not.
        // The filled triangle is still the voted state.
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(controlTint)
        .fixedSize()
        .disabled(isDisabled)
        .accessibilityLabel(Text(voteCount, format: .number))
        .accessibilityInputLabels([
            String(localized: hasVoted ? .buttonVoted : .buttonVote)
        ])
        .accessibilityValue(hasVoted ? String(localized: .accessibilityVoted) : String(localized: .accessibilityNotVoted))
        .accessibilityHint(accessibilityHintText)
    }
}
