#if os(macOS)
import AppKit

@MainActor
public final class SharedGalleryLayout {
    public var columnCount: Int = 4 {
        didSet {
            if oldValue != columnCount { collectionViewLayout.invalidateLayout() }
        }
    }

    public var metrics: GalleryMetrics {
        didSet { collectionViewLayout.invalidateLayout() }
    }

    public var showsSupplementaryDetail: Bool = false {
        didSet {
            if oldValue != showsSupplementaryDetail { collectionViewLayout.invalidateLayout() }
        }
    }

    public var supplementaryDetailHeight: CGFloat {
        didSet {
            if oldValue != supplementaryDetailHeight { collectionViewLayout.invalidateLayout() }
        }
    }

    /// The computed tile side from the most recent layout pass. Updated each time
    /// the section provider runs. Defaults to `metrics.minTileSide` until first layout.
    public private(set) var tileSide: CGFloat

    public lazy var collectionViewLayout: NSCollectionViewCompositionalLayout = {
        NSCollectionViewCompositionalLayout { [weak self] _, environment in
            guard let self else { return nil }

            let metrics = self.metrics
            let columns = max(self.columnCount, 1)
            let containerWidth = environment.container.effectiveContentSize.width
            let spacing = metrics.horizontalSpacing
            let insets = metrics.gridInsets
            let totalSpacing = CGFloat(columns - 1) * spacing
            let usableWidth = max(containerWidth - insets.left - insets.right - totalSpacing, 1)
            let side = max(1, floor(usableWidth / CGFloat(columns)))
            self.tileSide = max(metrics.minTileSide, side)

            let detailHeight = self.showsSupplementaryDetail ? max(0, self.supplementaryDetailHeight) : 0
            let itemHeight = side + detailHeight

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(side),
                heightDimension: .absolute(itemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(itemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: insets.top,
                leading: insets.left,
                bottom: insets.bottom,
                trailing: insets.right
            )
            section.interGroupSpacing = metrics.verticalSpacing
            return section
        }
    }()

    public init(
        columnCount: Int = 4,
        metrics: GalleryMetrics = .default,
        showsSupplementaryDetail: Bool = false,
        supplementaryDetailHeight: CGFloat? = nil
    ) {
        self.columnCount = columnCount
        self.metrics = metrics
        self.showsSupplementaryDetail = showsSupplementaryDetail
        self.supplementaryDetailHeight = supplementaryDetailHeight ?? metrics.supplementaryDetailHeight
        self.tileSide = metrics.minTileSide
    }

    public func invalidateLayout() {
        collectionViewLayout.invalidateLayout()
    }
}
#endif
