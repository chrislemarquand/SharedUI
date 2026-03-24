import AppKit

public struct GalleryZoomTransitionAnchor {
    public let itemIndex: Int

    public init(itemIndex: Int) {
        self.itemIndex = itemIndex
    }
}

@MainActor
public enum GalleryZoomTransitionSupport {
    public static func captureAnchor(
        selectedItemIndex: Int?,
        collectionView: NSCollectionView
    ) -> GalleryZoomTransitionAnchor? {
        if let selectedItemIndex,
           selectedItemIndex >= 0,
           selectedItemIndex < collectionView.numberOfItems(inSection: 0) {
            return GalleryZoomTransitionAnchor(itemIndex: selectedItemIndex)
        }

        let visible = collectionView.indexPathsForVisibleItems()
        guard !visible.isEmpty else { return nil }
        let visibleRect = collectionView.visibleRect
        let center = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        guard let currentLayout = collectionView.collectionViewLayout else { return nil }

        let best = visible.min { lhs, rhs in
            let lhsFrame = currentLayout.layoutAttributesForItem(at: lhs)?.frame ?? .zero
            let rhsFrame = currentLayout.layoutAttributesForItem(at: rhs)?.frame ?? .zero
            let lhsCenter = CGPoint(x: lhsFrame.midX, y: lhsFrame.midY)
            let rhsCenter = CGPoint(x: rhsFrame.midX, y: rhsFrame.midY)
            let lhsDistance = hypot(lhsCenter.x - center.x, lhsCenter.y - center.y)
            let rhsDistance = hypot(rhsCenter.x - center.x, rhsCenter.y - center.y)
            return lhsDistance < rhsDistance
        }

        guard let index = best?.item else { return nil }
        return GalleryZoomTransitionAnchor(itemIndex: index)
    }

    public static func restoreAnchor(
        _ anchor: GalleryZoomTransitionAnchor?,
        token: Int,
        currentToken: @escaping () -> Int,
        collectionView: NSCollectionView
    ) {
        guard let anchor else { return }
        guard anchor.itemIndex >= 0 else { return }
        guard collectionView.numberOfSections > 0 else { return }
        let currentCount = collectionView.numberOfItems(inSection: 0)
        guard anchor.itemIndex < currentCount else { return }

        let indexPath = IndexPath(item: anchor.itemIndex, section: 0)
        DispatchQueue.main.async { [weak collectionView] in
            guard let collectionView else { return }
            guard token == currentToken() else { return }
            guard collectionView.numberOfSections > 0 else { return }
            let liveCount = collectionView.numberOfItems(inSection: 0)
            guard anchor.itemIndex < liveCount else { return }
            collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
        }
    }
}
