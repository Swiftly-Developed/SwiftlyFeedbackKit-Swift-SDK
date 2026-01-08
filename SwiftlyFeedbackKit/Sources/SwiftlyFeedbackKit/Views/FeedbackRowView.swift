import SwiftUI

struct FeedbackCardView: View {
    let feedback: Feedback
    let onVote: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var cardBackground: Color {
        #if os(macOS)
        colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)
        #else
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
        #endif
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if config.showVoteCount {
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: onVote
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(feedback.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(config.expandDescriptionInList ? nil : 2)
                    .multilineTextAlignment(.leading)

                FeedbackRowMetadataView(feedback: feedback)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct FeedbackRowView: View {
    let feedback: Feedback
    let onVote: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if config.showVoteCount {
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: onVote
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(feedback.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(config.expandDescriptionInList ? nil : 2)

                FeedbackRowMetadataView(feedback: feedback)
            }
        }
        .padding(.vertical, 4)
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

    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var voteColor: Color {
        if !status.canVote {
            return .secondary.opacity(0.5)
        }
        if hasVoted {
            return theme.primaryColor.resolve(for: colorScheme)
        }
        return .secondary
    }

    private var isDisabled: Bool {
        !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .font(.system(size: 16, weight: .bold))
                Text(voteCount, format: .number)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
            }
            .foregroundStyle(voteColor)
            .frame(width: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct StatusBadge: View {
    let status: FeedbackStatus

    @Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var statusColor: Color {
        theme.statusColors.color(for: status)
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(.capsule)
    }
}

struct CategoryBadge: View {
    let category: FeedbackCategory

    @Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var categoryColor: Color {
        theme.categoryColors.color(for: category)
    }

    var body: some View {
        Text(category.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor.opacity(0.15))
            .foregroundStyle(categoryColor)
            .clipShape(.capsule)
    }
}
