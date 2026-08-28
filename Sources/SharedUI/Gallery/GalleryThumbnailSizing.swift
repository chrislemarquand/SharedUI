#if os(macOS)
import AppKit

/// Aspect-ratio-aware fitted sizing for a thumbnail rendered inside a square tile, shared by
/// any AppKit gallery-style cell (icon grid, filmstrip, ...). Keeping this single-sourced matters
/// beyond avoiding duplication: any cell that pins an overlay (a cloud badge, a pending-edit dot)
/// to the thumbnail image view's own bounds needs that view sized to the actual visible
/// (letterboxed) image, not the tile's full square — get the sizing wrong and the overlay floats
/// in the wrong place instead of sitting on the image's real corner.
public enum GalleryThumbnailSizing {
    public static func fittedSize(
        preferredAspectRatio: CGFloat?,
        fallbackImageSize: CGSize?,
        in side: CGFloat,
        imageInset: CGFloat
    ) -> CGSize {
        let availableSide = max(1, floor(side - imageInset * 2))
        let aspect: CGFloat
        // Prefer rendered image dimensions so layout tracks displayed content.
        if let fallbackImageSize, fallbackImageSize.width > 0, fallbackImageSize.height > 0 {
            aspect = fallbackImageSize.width / fallbackImageSize.height
        } else if let preferredAspectRatio, preferredAspectRatio > 0 {
            aspect = preferredAspectRatio
        } else {
            aspect = 1
        }

        if aspect >= 1 {
            let width = max(1, floor(availableSide))
            let height = max(1, floor(availableSide / aspect))
            return CGSize(width: width, height: height)
        } else {
            let width = max(1, floor(availableSide * aspect))
            let height = max(1, floor(availableSide))
            return CGSize(width: width, height: height)
        }
    }

    public static func resolvedImageSize(_ image: NSImage?) -> CGSize? {
        guard let image else { return nil }
        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
           bitmap.pixelsWide > 0,
           bitmap.pixelsHigh > 0 {
            return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           cgImage.width > 0,
           cgImage.height > 0 {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return nil
    }
}
#endif
