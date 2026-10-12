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

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var cardBackground: Color {
        #if os(macOS)
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)
        #else
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
        #endif
    }

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

    /// Whether translated text is currently on screen (drives the appended
    /// "Translated from" fragment in the composed accessibility label).
    private var isShowingTranslation: Bool {
        !isShowingOriginal && (translatedTitle != nil || translatedDescription != nil)
    }

    /// Builds a combined accessibility description for VoiceOver — reads the
    /// *displayed* text, so it takes the translation projection as input.
    var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(displayedTitle)
        parts.append(displayedDescription)
        if isShowingTranslation, let translationSourceName {
            parts.append(Strings.translatedFrom(translationSourceName))
        }
        if config.showStatusBadge {
            parts.append(Strings.accessibilityStatus(feedback.status.localizedDisplayName))
        }
        if config.showCategoryBadge {
            parts.append(Strings.accessibilityCategory(feedback.category.localizedDisplayName))
        }
        if config.showVoteCount {
            parts.append(Strings.accessibilityVoteCount(feedback.voteCount))
        }
        if feedback.commentCount > 0 && config.showCommentSection {
            parts.append(Strings.accessibilityCommentCount(feedback.commentCount))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if config.showVoteCount {
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: onVote
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayedTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(displayedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(config.expandDescriptionInList ? nil : 2)
                    .multilineTextAlignment(.leading)

                if let translationSourceName, let onToggleTranslation {
                    TranslationAffordanceView(
                        sourceLanguageName: translationSourceName,
                        isShowingOriginal: isShowingOriginal,
                        onToggle: onToggleTranslation
                    )
                }

                FeedbackRowMetadataView(feedback: feedback)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct FeedbackRowMetadataView: View {
    let feedback: Feedback

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    var body: some View {
        HStack(spacing: 8) {
            if config.showStatusBadge {
                StatusBadge(status: feedback.status)
            }

            if config.showCategoryBadge {
                CategoryBadge(category: feedback.category)
            }

            Spacer()

            if feedback.commentCount > 0 && config.showCommentSection {
                Label("\(feedback.commentCount)", systemImage: "bubble.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Strings.accessibilityCommentCount(feedback.commentCount))
            }
        }
        .padding(.top, 4)
    }
}

struct VoteButton: View {
    let voteCount: Int
    let hasVoted: Bool
    let status: FeedbackStatus
    let action: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var themeColor: Color {
        theme.primaryColor.resolve(for: colorScheme)
    }

    private var foregroundColor: Color {
        if !status.canVote {
            return .secondary.opacity(0.5)
        }
        return themeColor
    }

    private var backgroundColor: Color {
        if hasVoted {
            return themeColor.opacity(0.15)
        }
        return .clear
    }

    private var borderColor: Color {
        if !status.canVote {
            return .secondary.opacity(0.3)
        }
        return themeColor.opacity(0.5)
    }

    private var isDisabled: Bool {
        !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    private var accessibilityHintText: String {
        if !status.canVote {
            return Strings.accessibilityVotingClosed
        } else if hasVoted {
            return Strings.accessibilityUnvoteHint
        } else {
            return Strings.accessibilityVoteHint
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .font(.system(size: 14, weight: .bold))
                Text(voteCount, format: .number)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 44, height: 44)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(Strings.accessibilityVoteCount(voteCount))
        .accessibilityValue(hasVoted ? Strings.accessibilityVoted : Strings.accessibilityNotVoted)
        .accessibilityHint(accessibilityHintText)
    }
}

struct StatusBadge: View {
    let status: FeedbackStatus

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var statusColor: Color {
        theme.statusColors.color(for: status).resolve(for: colorScheme)
    }

    var body: some View {
        Text(status.localizedDisplayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(.capsule)
            .accessibilityLabel(Strings.accessibilityStatus(status.localizedDisplayName))
    }
}

struct CategoryBadge: View {
    let category: FeedbackCategory

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var categoryColor: Color {
        theme.categoryColors.color(for: category).resolve(for: colorScheme)
    }

    var body: some View {
        Text(category.localizedDisplayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor.opacity(0.15))
            .foregroundStyle(categoryColor)
            .clipShape(.capsule)
            .accessibilityLabel(Strings.accessibilityCategory(category.localizedDisplayName))
    }
}
