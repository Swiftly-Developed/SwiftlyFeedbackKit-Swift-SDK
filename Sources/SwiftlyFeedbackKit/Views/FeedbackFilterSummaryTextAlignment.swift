import SwiftUI

extension HorizontalAlignment {
    /// The leading edge of the "Filtered by" text, past the filter icon, so the stacked Clear
    /// button lines up with the text rather than the icon.
    private enum FilterSummaryText: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    static let filterSummaryText = HorizontalAlignment(FilterSummaryText.self)
}
