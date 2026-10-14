import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `FEEDBACK01` §6 and §6.7 — status, category, search text and sort combined over the loaded
/// collection, and the branch each combination drives.
@Suite("Feedback list displayed items")
struct FeedbackListDisplayedItemsTests {

    static let darkMode = FeedbackFixtures.make(
        title: "Dark mode", description: "Night reading", status: .inProgress,
        category: .featureRequest, voteCount: 186, commentCount: 24,
        createdAt: Date(timeIntervalSince1970: 100)
    )
    static let export = FeedbackFixtures.make(
        title: "Export to CSV", description: "Spreadsheet", status: .approved,
        category: .improvement, voteCount: 142, commentCount: 11,
        createdAt: Date(timeIntervalSince1970: 300)
    )
    static let crash = FeedbackFixtures.make(
        title: "Crash on launch", description: "Dark screen then quit", status: .inProgress,
        category: .bugReport, voteCount: 40, commentCount: 30,
        createdAt: Date(timeIntervalSince1970: 200)
    )
    static let shipped = FeedbackFixtures.make(
        title: "Widgets", description: "Home screen", status: .completed,
        category: .featureRequest, voteCount: 90, commentCount: 2,
        createdAt: Date(timeIntervalSince1970: 50)
    )
    static let all = [darkMode, export, crash, shipped]

    private func displayed(
        _ items: [Feedback] = Self.all,
        search: String = "",
        filter: FeedbackListFilter = FeedbackListFilter(),
        sort: FeedbackSortOption = .votes
    ) -> [Feedback] {
        FeedbackListViewModel.displayedItems(
            from: FeedbackListViewModel.sorted(items, by: sort),
            searchText: search,
            tokens: [],
            filter: filter
        )
    }

    @Test("No search and no filter shows everything, sorted")
    func unfilteredShowsAll() {
        #expect(displayed().map(\.title) == ["Dark mode", "Export to CSV", "Widgets", "Crash on launch"])
        #expect(displayed(sort: .newest).map(\.title) == ["Export to CSV", "Crash on launch", "Dark mode", "Widgets"])
        #expect(displayed(sort: .comments).first?.title == "Crash on launch")
    }

    @Test("A status filter narrows client-side")
    func statusFilter() {
        let items = displayed(filter: FeedbackListFilter(status: .inProgress))
        #expect(items.map(\.title) == ["Dark mode", "Crash on launch"])
    }

    @Test("A category filter narrows client-side")
    func categoryFilter() {
        let items = displayed(filter: FeedbackListFilter(category: .featureRequest))
        #expect(items.map(\.title) == ["Dark mode", "Widgets"])
    }

    @Test("Status AND category AND search combine")
    func everythingCombines() {
        let both = FeedbackListFilter(status: .inProgress, category: .bugReport)
        #expect(displayed(filter: both).map(\.title) == ["Crash on launch"])
        #expect(displayed(search: "dark", filter: both).map(\.title) == ["Crash on launch"])
        #expect(displayed(search: "dark", filter: FeedbackListFilter(status: .inProgress)).map(\.title) == ["Dark mode", "Crash on launch"])
        #expect(displayed(search: "csv", filter: both).isEmpty)
    }

    @Test("Project-empty wins over every filter and search")
    func projectEmptyBranch() {
        let branch = FeedbackListViewModel.branch(
            loaded: [], displayed: [], isSearchActive: true, isFilterActive: true
        )
        #expect(branch == .projectEmpty)
    }

    @Test("Filters that match nothing show filtered-empty, with or without search text")
    func filteredEmptyBranch() {
        let filter = FeedbackListFilter(status: .rejected)
        let none = displayed(filter: filter)
        #expect(none.isEmpty)
        #expect(FeedbackListViewModel.branch(loaded: Self.all, displayed: none, isSearchActive: false, isFilterActive: true) == .filteredEmpty)
        #expect(FeedbackListViewModel.branch(loaded: Self.all, displayed: none, isSearchActive: true, isFilterActive: true) == .filteredEmpty)
    }

    @Test("Search text alone that matches nothing shows search-empty")
    func searchEmptyBranch() {
        let none = displayed(search: "zzz")
        #expect(none.isEmpty)
        #expect(FeedbackListViewModel.branch(loaded: Self.all, displayed: none, isSearchActive: true, isFilterActive: false) == .searchEmpty)
    }

    @Test("Anything left to show is the populated branch")
    func populatedBranch() {
        let some = displayed(filter: FeedbackListFilter(category: .improvement))
        #expect(some.count == 1)
        #expect(FeedbackListViewModel.branch(loaded: Self.all, displayed: some, isSearchActive: false, isFilterActive: true) == .populated)
    }
}
