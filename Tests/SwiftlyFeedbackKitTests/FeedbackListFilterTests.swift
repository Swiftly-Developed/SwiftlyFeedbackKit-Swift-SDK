import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `FEEDBACK01` §6.5 and §6.6 — the filter state behind the Sort & Filter menu and the
/// "Filtered by … Clear" row.
@Suite("Feedback list filter")
struct FeedbackListFilterTests {

    @Test("An empty filter is inactive and has no summary")
    func emptyFilterIsInactive() {
        let filter = FeedbackListFilter()
        #expect(filter.isActive == false)
        #expect(filter.activeCount == 0)
        #expect(filter.summaryComponents.isEmpty)
    }

    @Test("A status or a category alone activates the filter")
    func singleFilterActivates() {
        let status = FeedbackListFilter(status: .inProgress)
        #expect(status.isActive)
        #expect(status.activeCount == 1)
        #expect(status.summaryComponents == [.status(.inProgress)])

        let category = FeedbackListFilter(category: .bugReport)
        #expect(category.isActive)
        #expect(category.activeCount == 1)
        #expect(category.summaryComponents == [.category(.bugReport)])
    }

    @Test("With both filters active, category comes first, then status")
    func categoryPrecedesStatus() {
        let filter = FeedbackListFilter(status: .inProgress, category: .bugReport)
        #expect(filter.activeCount == 2)
        #expect(filter.summaryComponents == [.category(.bugReport), .status(.inProgress)])
    }

    @Test("Summary text names the plural category, then the status, in that order")
    func summaryTextOrder() throws {
        let filter = FeedbackListFilter(status: .inProgress, category: .bugReport)
        let text = filter.summaryText
        let category = FeedbackCategory.bugReport.localizedPluralName
        let status = FeedbackStatus.inProgress.localizedDisplayName
        let categoryRange = try #require(text.range(of: category))
        let statusRange = try #require(text.range(of: status))
        #expect(categoryRange.upperBound <= statusRange.lowerBound)

        let spoken = filter.spokenSummaryText
        #expect(spoken.contains(category))
        #expect(spoken.contains(status))
    }

    @Test("A single active filter's summary is just its name")
    func singleSummaryIsTheName() {
        #expect(FeedbackListFilter(category: .improvement).summaryText == FeedbackCategory.improvement.localizedPluralName)
        #expect(FeedbackListFilter(status: .approved).summaryText == FeedbackStatus.approved.localizedDisplayName)
    }

    @Test("Clear removes status and category together")
    func clearRemovesBoth() {
        var filter = FeedbackListFilter(status: .pending, category: .other)
        filter.clear()
        #expect(filter == FeedbackListFilter())
        #expect(filter.isActive == false)
    }

    @Test("Matching is status AND category")
    func matchingIsAnd() {
        let item = FeedbackFixtures.make(status: .inProgress, category: .bugReport)
        #expect(FeedbackListFilter().matches(item))
        #expect(FeedbackListFilter(status: .inProgress).matches(item))
        #expect(FeedbackListFilter(category: .bugReport).matches(item))
        #expect(FeedbackListFilter(status: .inProgress, category: .bugReport).matches(item))
        #expect(FeedbackListFilter(status: .inProgress, category: .improvement).matches(item) == false)
        #expect(FeedbackListFilter(status: .completed, category: .bugReport).matches(item) == false)
    }

    @Test("The menu value reads 'Filtered by …' while filtered and the sort name otherwise")
    func menuAccessibilityValue() {
        let unfiltered = FeedbackListFilter()
        #expect(unfiltered.menuAccessibilityValue(sort: .newest) == FeedbackSortOption.newest.localizedName)

        let filtered = FeedbackListFilter(category: .bugReport)
        let value = filtered.menuAccessibilityValue(sort: .newest)
        #expect(value != FeedbackSortOption.newest.localizedName)
        #expect(value.contains(FeedbackCategory.bugReport.localizedPluralName))
    }

    @Test("The four plural category names are distinct and differ from the singular names")
    func pluralNamesAreDistinct() {
        let plurals = FeedbackCategory.allCases.map(\.localizedPluralName)
        #expect(Set(plurals).count == 4)
        for category in FeedbackCategory.allCases where category != .other {
            #expect(category.localizedPluralName != category.localizedDisplayName)
        }
    }
}
