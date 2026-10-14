import Testing
@testable import SwiftlyFeedbackKit

/// `FEEDBACK01` §6.4 — every row of the vote table, from the one resolver both list styles and
/// the detail screen consume.
@Suite("Vote presentation")
struct VotePresentationTests {

    struct Cell: Sendable, CustomTestStringConvertible {
        let name: String
        let showVoteCount: Bool
        let isPlaceholder: Bool
        let canVote: Bool
        let hasVoted: Bool
        let allowUndoVote: Bool
        let expected: VotePresentation

        var testDescription: String { name }
    }

    static let cells: [Cell] = [
        Cell(name: "showVoteCount false", showVoteCount: false, isPlaceholder: false, canVote: true, hasVoted: false, allowUndoVote: true, expected: .hidden),
        Cell(name: "showVoteCount false beats placeholder", showVoteCount: false, isPlaceholder: true, canVote: true, hasVoted: false, allowUndoVote: true, expected: .hidden),
        Cell(name: "skeleton", showVoteCount: true, isPlaceholder: true, canVote: true, hasVoted: false, allowUndoVote: true, expected: .placeholder),
        Cell(name: "skeleton beats closed", showVoteCount: true, isPlaceholder: true, canVote: false, hasVoted: false, allowUndoVote: true, expected: .placeholder),
        Cell(name: "closed, not voted", showVoteCount: true, isPlaceholder: false, canVote: false, hasVoted: false, allowUndoVote: true, expected: .closed),
        Cell(name: "closed, voted", showVoteCount: true, isPlaceholder: false, canVote: false, hasVoted: true, allowUndoVote: false, expected: .closed),
        Cell(name: "votable, not voted", showVoteCount: true, isPlaceholder: false, canVote: true, hasVoted: false, allowUndoVote: true, expected: .vote),
        Cell(name: "votable, not voted, undo off", showVoteCount: true, isPlaceholder: false, canVote: true, hasVoted: false, allowUndoVote: false, expected: .vote),
        Cell(name: "votable, voted, undo allowed", showVoteCount: true, isPlaceholder: false, canVote: true, hasVoted: true, allowUndoVote: true, expected: .unvote),
        Cell(name: "votable, voted, undo not allowed", showVoteCount: true, isPlaceholder: false, canVote: true, hasVoted: true, allowUndoVote: false, expected: .votedLocked),
    ]

    @Test("Each cell of the vote table resolves to its presentation", arguments: VotePresentationTests.cells)
    func resolvesEveryCell(_ cell: Cell) {
        let resolved = VotePresentation.resolve(
            showVoteCount: cell.showVoteCount,
            isPlaceholder: cell.isPlaceholder,
            canVote: cell.canVote,
            hasVoted: cell.hasVoted,
            allowUndoVote: cell.allowUndoVote
        )
        #expect(resolved == cell.expected)
    }

    @Test("Every closed status resolves to a count, never a button")
    func closedIsNeverAButton() {
        for status in FeedbackStatus.allCases where !status.canVote {
            for hasVoted in [false, true] {
                for allowUndo in [false, true] {
                    let resolved = VotePresentation.resolve(
                        showVoteCount: true, isPlaceholder: false,
                        canVote: status.canVote, hasVoted: hasVoted, allowUndoVote: allowUndo
                    )
                    #expect(resolved == .closed)
                    #expect(resolved.isButton == false)
                    #expect(resolved.isEnabled == false)
                }
            }
        }
        // The paired present twin: a votable status does resolve to a button.
        let open = VotePresentation.resolve(
            showVoteCount: true, isPlaceholder: false, canVote: true, hasVoted: false, allowUndoVote: true
        )
        #expect(open.isButton)
    }

    @Test("Interaction, emphasis and the value channel per presentation")
    func interactionAndAccessibility() {
        #expect(VotePresentation.hidden.isButton == false)
        #expect(VotePresentation.placeholder.isButton == false)
        #expect(VotePresentation.placeholder.isAccessibilityHidden)

        #expect(VotePresentation.vote.isEnabled)
        #expect(VotePresentation.vote.isProminent == false)
        #expect(VotePresentation.vote.accessibilityValue == .notVoted)
        #expect(VotePresentation.vote.accessibilityHint == .vote)

        #expect(VotePresentation.unvote.isEnabled)
        #expect(VotePresentation.unvote.isProminent)
        #expect(VotePresentation.unvote.accessibilityValue == .voted)
        #expect(VotePresentation.unvote.accessibilityHint == .unvote)

        #expect(VotePresentation.closed.accessibilityValue == .votingClosed)
        #expect(VotePresentation.closed.isAccessibilityHidden == false)
    }

    /// `QA-UI09` `-05` / F5: the disabled voted control must not offer the unvote action it refuses.
    @Test("Voted without undo is disabled and never announces the unvote hint")
    func votedLockedHintIsCorrected() {
        let locked = VotePresentation.votedLocked
        #expect(locked.isButton)
        #expect(locked.isEnabled == false)
        #expect(locked.isProminent)
        #expect(locked.accessibilityValue == .voted)
        #expect(locked.accessibilityHint == .votesCannotBeRemoved)
        #expect(locked.accessibilityHint != .unvote)
    }
}
