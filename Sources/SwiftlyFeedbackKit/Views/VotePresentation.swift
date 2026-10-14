import Foundation

/// What the vote control is, for one item, on every surface that draws one.
///
/// The single source for interaction, emphasis and the accessibility value and hint. The
/// Showcase capsule, the Classic column and the detail screen all read it, so they cannot
/// disagree about whether a vote can be removed.
enum VotePresentation: Equatable, Sendable {
    /// `showVoteCount` is off: nothing is drawn.
    case hidden
    /// Skeleton: a grey shape of the same size, hidden from accessibility.
    case placeholder
    /// Completed or rejected: the count as plain text, not a control.
    case closed
    /// Votable and not voted.
    case vote
    /// Voted, and the host allows removing it.
    case unvote
    /// Voted, and the host does not allow removing it: a disabled control.
    case votedLocked

    enum AccessibilityValue: Equatable, Sendable {
        case notVoted
        case voted
        case votingClosed

        var localizedText: String {
            switch self {
            case .notVoted: String(localized: .accessibilityNotVoted)
            case .voted: String(localized: .accessibilityVoted)
            case .votingClosed: String(localized: .accessibilityVotingClosed)
            }
        }
    }

    enum AccessibilityHint: Equatable, Sendable {
        case vote
        case unvote
        case votesCannotBeRemoved

        var localizedText: String {
            switch self {
            case .vote: String(localized: .accessibilityVoteHint)
            case .unvote: String(localized: .accessibilityUnvoteHint)
            case .votesCannotBeRemoved: String(localized: .accessibilityVoteLockedHint)
            }
        }
    }

    static func resolve(
        showVoteCount: Bool,
        isPlaceholder: Bool,
        canVote: Bool,
        hasVoted: Bool,
        allowUndoVote: Bool
    ) -> VotePresentation {
        guard showVoteCount else { return .hidden }
        if isPlaceholder { return .placeholder }
        guard canVote else { return .closed }
        guard hasVoted else { return .vote }
        return allowUndoVote ? .unvote : .votedLocked
    }

    @MainActor
    static func resolve(for feedback: Feedback, isPlaceholder: Bool, configuration: SwiftlyFeedbackConfiguration) -> VotePresentation {
        resolve(
            showVoteCount: configuration.showVoteCount,
            isPlaceholder: isPlaceholder,
            canVote: feedback.status.canVote,
            hasVoted: feedback.hasVoted,
            allowUndoVote: configuration.allowUndoVote
        )
    }

    var isButton: Bool {
        switch self {
        case .vote, .unvote, .votedLocked: true
        case .hidden, .placeholder, .closed: false
        }
    }

    var isEnabled: Bool {
        switch self {
        case .vote, .unvote: true
        case .hidden, .placeholder, .closed, .votedLocked: false
        }
    }

    /// Filled in the host tint once voted.
    var isProminent: Bool {
        switch self {
        case .unvote, .votedLocked: true
        case .hidden, .placeholder, .closed, .vote: false
        }
    }

    var isAccessibilityHidden: Bool {
        switch self {
        case .hidden, .placeholder: true
        case .closed, .vote, .unvote, .votedLocked: false
        }
    }

    var accessibilityValue: AccessibilityValue? {
        switch self {
        case .hidden, .placeholder: nil
        case .closed: .votingClosed
        case .vote: .notVoted
        case .unvote, .votedLocked: .voted
        }
    }

    var accessibilityHint: AccessibilityHint? {
        switch self {
        case .hidden, .placeholder, .closed: nil
        case .vote: .vote
        case .unvote: .unvote
        case .votedLocked: .votesCannotBeRemoved
        }
    }
}
