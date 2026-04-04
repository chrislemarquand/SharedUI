import SwiftUI

struct TokenFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(subviews: subviews, width: proposal.width ?? 0)
        guard !rows.isEmpty else { return CGSize(width: proposal.width ?? 0, height: 0) }
        let height = rows.map(\.height).reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for (itemIndex, item) in row.items.enumerated() {
                let yOffset = (row.height - item.size.height) / 2
                // Stretch the last item on each row to fill remaining width so
                // the text input field always expands to the right edge.
                let isLast = itemIndex == row.items.count - 1
                let width = isLast ? max(item.size.width, bounds.maxX - x) : item.size.width
                item.subview.place(
                    at: CGPoint(x: x, y: y + yOffset),
                    proposal: ProposedViewSize(width: width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        var items: [RowItem] = []
        var height: CGFloat { items.map(\.size.height).max() ?? 0 }
    }

    private func computeRows(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let wouldOverflow = !rows.last!.items.isEmpty && rowWidth + size.width > width
            if wouldOverflow {
                rows.append(Row())
                rowWidth = 0
            }
            rows[rows.count - 1].items.append(RowItem(subview: subview, size: size))
            rowWidth += size.width + spacing
        }

        return rows.filter { !$0.items.isEmpty }
    }
}
