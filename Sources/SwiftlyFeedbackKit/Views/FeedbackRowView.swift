import SwiftUI

struct FeedbackRowView: View {
    let feedback: Feedback
    let onVote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VoteButton(
                voteCount: feedback.voteCount,
                hasVoted: feedback.hasVoted,
                action: onVote
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(feedback.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    StatusBadge(status: feedback.status)
                    CategoryBadge(category: feedback.category)

                    Spacer()

                    if feedback.commentCount > 0 {
                        Label("\(feedback.commentCount)", systemImage: "bubble.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VoteButton: View {
    let voteCount: Int
    let hasVoted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(voteCount)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(hasVoted ? .blue : .secondary)
            .frame(width: 44)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: FeedbackStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: return .gray.opacity(0.2)
        case .approved: return .blue.opacity(0.2)
        case .inProgress: return .orange.opacity(0.2)
        case .completed: return .green.opacity(0.2)
        case .rejected: return .red.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: return .gray
        case .approved: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .rejected: return .red
        }
    }
}

struct CategoryBadge: View {
    let category: FeedbackCategory

    var body: some View {
        Text(category.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.1))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }
}
