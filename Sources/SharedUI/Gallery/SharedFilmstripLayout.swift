#if os(macOS)
import AppKit

/// A single horizontally-scrolling row of square-ish tiles, sized by a fixed row height rather
/// than `SharedGalleryLayout`'s fixed-column-count-of-the-container-width approach — the two
/// are semantically different knobs (row height vs. column count) and this is not a drop-in
/// reuse of that type.
@MainActor
public final class SharedFilmstripLayout {
    public var rowHeight: CGFloat {
        didSet {
            if oldValue != rowHeight { collectionViewLayout.invalidateLayout() }
        }
    }

    public var metrics: GalleryMetrics {
        didSet { collectionViewLayout.invalidateLayout() }
    }

    public lazy var collectionViewLayout: NSCollectionViewCompositionalLayout = {
        let layout = NSCollectionViewCompositionalLayout { [weak self] _, _ in
            guard let self else { return nil }

            let metrics = self.metrics
            let side = max(1, self.rowHeight)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(side),
                heightDimension: .absolute(side)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(side),
                heightDimension: .absolute(side)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = metrics.horizontalSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: metrics.gridInsets.top,
                leading: metrics.gridInsets.left,
                bottom: metrics.gridInsets.bottom,
                trailing: metrics.gridInsets.right
            )
            return section
        }
        let configuration = NSCollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .horizontal
        layout.configuration = configuration
        return layout
    }()

    public init(rowHeight: CGFloat = 96, metrics: GalleryMetrics = .default) {
        self.rowHeight = rowHeight
        self.metrics = metrics
    }

    public func invalidateLayout() {
        collectionViewLayout.invalidateLayout()
    }
}
#endif
