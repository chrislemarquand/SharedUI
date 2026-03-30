import AppKit

@MainActor
public final class SharedGalleryCollectionView: NSCollectionView {
    public var contextMenuProvider: ((IndexPath) -> NSMenu?)?
    override public func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let indexPath = indexPathForItem(at: point) else { return nil }
        return contextMenuProvider?(indexPath)
    }
}
