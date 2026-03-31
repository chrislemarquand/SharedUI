import AppKit
import ImageIO
import QuickLookThumbnailing

/// Stateless thumbnail generation utilities.
/// Does not perform caching or request deduplication — those are caller responsibilities.
public enum ThumbnailGenerator {

    /// Generate an orientation-corrected thumbnail using CGImageSource.
    /// Returns nil if the file cannot be opened or decoded as an image source.
    /// Synchronous and CPU-bound — call off the main actor.
    public static func generateOrientedThumbnail(fileURL: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(32, Int(maxPixelSize)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: .zero)
    }

    /// Generate a thumbnail via QLThumbnailGenerator.
    /// Returns nil if QuickLook can only produce an icon representation.
    public static func generateQuickLookThumbnail(fileURL: URL, maxPixelSize: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: maxPixelSize, height: maxPixelSize),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                guard let thumbnail, thumbnail.type != .icon else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: thumbnail.nsImage)
            }
        }
    }

    /// Returns true if the file extension indicates a raster image that CGImageSource can orient-correct.
    public static func isLikelyImageFile(_ fileURL: URL) -> Bool {
        let imageExtensions: Set<String> = [
            "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff",
            "gif", "bmp", "webp", "dng", "cr2", "cr3", "arw", "nef", "raf", "orf"
        ]
        return imageExtensions.contains(fileURL.pathExtension.lowercased())
    }

    /// Returns a workspace icon for the file, sized to `side` × `side` points.
    /// Always succeeds — worst case is a generic document icon.
    public static func thumbnailFallbackIcon(for fileURL: URL, side: CGFloat) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: side, height: side)
        return icon
    }

    /// Returns true if the disk-cached thumbnail is older than the source file.
    /// Both URLs must be file URLs. Returns false if either modification date cannot be read —
    /// callers should treat an unreadable source as a cache hit to avoid regenerating on every access.
    public static func isDiskCacheStale(sourceURL: URL, cacheURL: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let sourceMod = (try? sourceURL.resourceValues(forKeys: keys))?.contentModificationDate,
              let cacheMod = (try? cacheURL.resourceValues(forKeys: keys))?.contentModificationDate
        else { return false }
        return sourceMod > cacheMod
    }
}
