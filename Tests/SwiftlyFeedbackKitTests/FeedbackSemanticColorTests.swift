import Foundation
import Testing

/// FEEDBACK01 G9: the list draws with SwiftUI's semantic and system colours and the host's
/// own tint and status colours, unaltered. Those adapt to light, dark and Increase Contrast on
/// their own, so the SDK computes no colour, measures no contrast and reads no contrast setting.
@Suite("Showcase uses system colours")
struct FeedbackSemanticColorTests {

    private static let bannedTokens = [
        "Color(red:",
        "Color(hue:",
        "Color(white:",
        "Color.Resolved(",
        ".resolve(in:",
        "linearRed",
        "luminance",
        "colorSchemeContrast",
        "FeedbackLegibleColor",
        "hex:",
    ]

    private static let showcaseDirectory = "Sources/SwiftlyFeedbackKit/Views/Showcase"

    private static let sharedFiles = [
        "Sources/SwiftlyFeedbackKit/Views/FeedbackListFilterSummaryRow.swift",
        "Sources/SwiftlyFeedbackKit/Views/FeedbackListSortFilterMenu.swift",
        "Sources/SwiftlyFeedbackKit/Views/FeedbackFilterEmptyStateView.swift",
        "Sources/SwiftlyFeedbackKit/Views/VoteButton.swift",
    ]

    private static func scannedFiles() throws -> [String] {
        let directory = WorkspaceSourceTree.packageRoot.appendingPathComponent(showcaseDirectory)
        let showcase = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".swift") }
            .map { "\(showcaseDirectory)/\($0)" }
        return showcase.sorted() + sharedFiles
    }

    @Test("No computed colours, contrast maths or contrast-setting branches")
    func noCustomColourAdjustment() throws {
        let files = try Self.scannedFiles()
        #expect(files.count > 15, "The Showcase directory scan found \(files.count) files; the path moved.")
        for file in files {
            let source = try WorkspaceSourceTree.sdkSource(file)
            for token in Self.bannedTokens {
                #expect(!source.contains(token), "\(file) contains \(token)")
            }
        }
    }

    @Test("The contrast-adjustment helper is gone")
    func legibleColorHelperIsDeleted() {
        let url = WorkspaceSourceTree.packageRoot
            .appendingPathComponent("Sources/SwiftlyFeedbackKit/Views/FeedbackLegibleColor.swift")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Description, footer facts, closed count and filter sentence are secondary text")
    func supportingTextIsSecondary() throws {
        let card = try WorkspaceSourceTree.sdkSource("\(Self.showcaseDirectory)/FeedbackShowcaseCard.swift")
        let description = try #require(
            WorkspaceSourceTree.slice(card, from: "Text(displayedDescription)", to: ".padding(.top, descriptionGap)")
        )
        #expect(description.contains(".foregroundStyle(.secondary)"))

        let facts = try WorkspaceSourceTree.sdkSource("\(Self.showcaseDirectory)/FeedbackShowcaseFooterFacts.swift")
        #expect(facts.contains(".foregroundStyle(.secondary)"))
        #expect(!facts.contains(".foregroundStyle(.primary)"))

        let capsule = try WorkspaceSourceTree.sdkSource("\(Self.showcaseDirectory)/FeedbackShowcaseVoteCapsule.swift")
        let closed = try #require(WorkspaceSourceTree.slice(capsule, from: "case .closed:", to: "case .placeholder:"))
        #expect(closed.contains(".foregroundStyle(.secondary)"))

        let summary = try WorkspaceSourceTree.sdkSource(Self.sharedFiles[0])
        #expect(summary.contains(".foregroundStyle(.secondary)"))
    }

    @Test("Host tint and status colours are used as resolved from the theme")
    func hostColoursAreUsedAsGiven() throws {
        let eyebrow = try WorkspaceSourceTree.sdkSource("\(Self.showcaseDirectory)/FeedbackStatusEyebrowView.swift")
        #expect(eyebrow.contains("statusColors.color(for: status).resolve(for: colorScheme)"))

        let voteButton = try WorkspaceSourceTree.sdkSource(Self.sharedFiles[3])
        #expect(voteButton.contains("primaryColor.resolve(for: colorScheme)"))
        #expect(!voteButton.contains("primaryColor == .default"))
    }
}
