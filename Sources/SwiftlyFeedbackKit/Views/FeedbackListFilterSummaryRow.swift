import SwiftUI

/// "Filtered by Bug Reports · In Progress   Clear": the in-list sign that the Sort & Filter
/// menu narrowed what is shown. Present only while a status or category filter is active.
///
/// The text wraps at large sizes with Clear on the first line's trailing edge; at
/// accessibility sizes Clear moves below the text, aligned with it. Nothing truncates.
struct FeedbackListFilterSummaryRow: View {
    let filter: FeedbackListFilter
    let onClear: () -> Void

    @SwiftUI.Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var spacing = 8

    /// The localized sentence with the filter names in bold primary text; the rest takes the
    /// row's secondary style. The names are found by range, so the catalog keeps control of
    /// word order.
    private var summary: AttributedString {
        let names = filter.summaryText
        var sentence = AttributedString(String(localized: .filterSummaryFilteredBy(names)))
        if let range = sentence.range(of: names) {
            sentence[range].inlinePresentationIntent = .stronglyEmphasized
            sentence[range].foregroundColor = Color.primary
        }
        return sentence
    }

    var body: some View {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        let label = Label {
            Text(summary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .alignmentGuide(.filterSummaryText) { $0[.leading] }
        } icon: {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.tint)
        }
        .labelStyle(FeedbackShowcaseBaselineLabelStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(filter.spokenFilteredByText)
        .accessibilityAction(named: String(localized: .accessibilityFilterClearAction), onClear)
        .accessibilityIdentifier("fbk-filter-summary")
        let clear = Button(action: onClear) {
            Text(String(localized: .filterSummaryClear))
                .bold()
                .foregroundStyle(.tint)
                .frame(
                    minWidth: FeedbackShowcaseMetrics.minimumHitSize,
                    minHeight: FeedbackShowcaseMetrics.minimumHitSize,
                    alignment: .leading
                )
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(String(localized: .accessibilityFilterClearAction))
        .accessibilityIdentifier("fbk-filter-summary-clear")

        Group {
            if isAccessibilitySize {
                VStack(alignment: .filterSummaryText, spacing: 0) {
                    label
                    clear
                        .alignmentGuide(.filterSummaryText) { $0[.leading] }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: spacing) {
                    label
                    clear
                }
            }
        }
        .font(.subheadline)
    }
}
