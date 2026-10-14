import SwiftUI

/// Places its subviews in a row when their ideal widths fit the offered width, otherwise in a
/// leading-aligned column where each may wrap.
///
/// `ViewThatFits` makes the same choice but keeps a second, hidden copy of every subview, which
/// the accessibility audit reports as text that cannot grow or may clip. This layout holds one.
struct FeedbackShowcaseRowOrStackLayout: Layout {
    enum RowAlignment {
        case center
        case firstTextBaseline
    }

    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    var rowAlignment: RowAlignment = .center
    /// In a row, pins the last subview to the trailing edge, as a `Spacer` before it would.
    var pinsLastToTrailingEdge = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = idealRowWidth(idealSizes)
        if fitsInRow(rowWidth, proposal: proposal) {
            let width = pinsLastToTrailingEdge ? (proposal.width ?? rowWidth) : rowWidth
            return CGSize(width: width, height: rowHeight(subviews: subviews, sizes: idealSizes))
        }
        let column = ProposedViewSize(width: proposal.width, height: nil)
        let sizes = subviews.map { $0.sizeThatFits(column) }
        let height = sizes.map(\.height).reduce(0, +) + verticalSpacing * CGFloat(max(0, sizes.count - 1))
        return CGSize(width: proposal.width ?? sizes.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rowWidth = idealRowWidth(idealSizes)
        guard fitsInRow(rowWidth, proposal: ProposedViewSize(width: bounds.width, height: nil)) else {
            let column = ProposedViewSize(width: bounds.width, height: nil)
            var y = bounds.minY
            for subview in subviews {
                let size = subview.sizeThatFits(column)
                subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: column)
                y += size.height + verticalSpacing
            }
            return
        }

        let baselines = subviews.indices.map { index in
            subviews[index].dimensions(in: ProposedViewSize(idealSizes[index]))[VerticalAlignment.firstTextBaseline]
        }
        let maxBaseline = baselines.max() ?? 0
        let height = rowHeight(subviews: subviews, sizes: idealSizes)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let size = idealSizes[index]
            if pinsLastToTrailingEdge, index == subviews.count - 1 {
                x = bounds.maxX - size.width
            }
            let y: CGFloat = switch rowAlignment {
            case .center: bounds.minY + (height - size.height) / 2
            case .firstTextBaseline: bounds.minY + maxBaseline - baselines[index]
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
        }
    }

    private func idealRowWidth(_ sizes: [CGSize]) -> CGFloat {
        sizes.map(\.width).reduce(0, +) + horizontalSpacing * CGFloat(max(0, sizes.count - 1))
    }

    private func fitsInRow(_ rowWidth: CGFloat, proposal: ProposedViewSize) -> Bool {
        guard let width = proposal.width, width.isFinite else { return true }
        return rowWidth <= width
    }

    private func rowHeight(subviews: Subviews, sizes: [CGSize]) -> CGFloat {
        switch rowAlignment {
        case .center:
            return sizes.map(\.height).max() ?? 0
        case .firstTextBaseline:
            let dimensions = subviews.indices.map { subviews[$0].dimensions(in: ProposedViewSize(sizes[$0])) }
            let ascent = dimensions.map { $0[VerticalAlignment.firstTextBaseline] }.max() ?? 0
            let descent = dimensions.map { $0.height - $0[VerticalAlignment.firstTextBaseline] }.max() ?? 0
            return ascent + descent
        }
    }
}
