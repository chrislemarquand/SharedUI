#if os(macOS)
import AppKit

public struct GalleryMetrics: Sendable {
    public var gridInsets: NSEdgeInsets
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat
    public var minTileSide: CGFloat
    public var thumbnailCornerRadius: CGFloat
    public var imageInset: CGFloat
    public var supplementaryDetailHeight: CGFloat

    public init(
        gridInsets: NSEdgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18),
        horizontalSpacing: CGFloat = 14,
        verticalSpacing: CGFloat = 16,
        minTileSide: CGFloat = 40,
        thumbnailCornerRadius: CGFloat = 8,
        imageInset: CGFloat = 4,
        supplementaryDetailHeight: CGFloat = 28
    ) {
        self.gridInsets = gridInsets
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.minTileSide = minTileSide
        self.thumbnailCornerRadius = thumbnailCornerRadius
        self.imageInset = imageInset
        self.supplementaryDetailHeight = supplementaryDetailHeight
    }

    public static let `default` = GalleryMetrics()
}
#endif
