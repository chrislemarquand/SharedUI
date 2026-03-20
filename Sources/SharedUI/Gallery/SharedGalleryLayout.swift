import AppKit

@MainActor
public final class SharedGalleryLayout: NSCollectionViewFlowLayout {
    public var columnCount: Int = 4 {
        didSet {
            if oldValue != columnCount {
                invalidateLayout()
            }
        }
    }

    public var metrics: GalleryMetrics {
        didSet {
            sectionInset = metrics.gridInsets
            minimumInteritemSpacing = metrics.horizontalSpacing
            minimumLineSpacing = metrics.verticalSpacing
            invalidateLayout()
        }
    }

    public var showsSupplementaryDetail: Bool = false {
        didSet {
            if oldValue != showsSupplementaryDetail {
                invalidateLayout()
            }
        }
    }

    public var supplementaryDetailHeight: CGFloat {
        didSet {
            if oldValue != supplementaryDetailHeight {
                invalidateLayout()
            }
        }
    }

    public var tileSide: CGFloat {
        max(metrics.minTileSide, floor(itemSize.width))
    }

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
        super.init()
        sectionInset = metrics.gridInsets
        minimumInteritemSpacing = metrics.horizontalSpacing
        minimumLineSpacing = metrics.verticalSpacing
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func prepare() {
        super.prepare()
        guard let collectionView else { return }

        let columns = max(columnCount, 1)
        let usableWidth = max(
            collectionView.bounds.width - sectionInset.left - sectionInset.right - CGFloat(columns - 1) * minimumInteritemSpacing,
            1
        )
        let side = max(1, floor(usableWidth / CGFloat(columns)))
        let detailHeight = showsSupplementaryDetail ? max(0, supplementaryDetailHeight) : 0
        itemSize = NSSize(width: side, height: side + detailHeight)
    }

    override public func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        true
    }
}
