#if os(macOS)
import AppKit

public enum GallerySelectionStyling {
    public static var tileSelectionBackgroundColor: NSColor {
        NSColor.unemphasizedSelectedContentBackgroundColor
    }

    @MainActor
    public static func resolvedTileSelectionBackgroundCGColor(for view: NSView?) -> CGColor {
        let dynamicColor = tileSelectionBackgroundColor
        guard let appearance = view?.effectiveAppearance else {
            return dynamicColor.cgColor
        }
        var resolved = dynamicColor.cgColor
        appearance.performAsCurrentDrawingAppearance {
            resolved = dynamicColor.cgColor
        }
        return resolved
    }

    /// Resolves the system accent colour for the given view's effective appearance.
    /// Use this instead of `NSColor.controlAccentColor.cgColor` so the colour is
    /// correctly adapted to the view's current light/dark context.
    @MainActor
    public static func resolvedAccentCGColor(for view: NSView?) -> CGColor {
        let color = NSColor.controlAccentColor
        guard let appearance = view?.effectiveAppearance else { return color.cgColor }
        var resolved = color.cgColor
        appearance.performAsCurrentDrawingAppearance { resolved = color.cgColor }
        return resolved
    }

    /// Mirrors `NSTableRowView.isEmphasized`'s semantics for custom-drawn collection view
    /// selection: emphasized only when the app is active, the window is key, AND first
    /// responder is within the gallery itself — not merely because the window is key.
    /// This keeps a gallery/icon tile's selection colour consistent with the sidebar's
    /// native table-row behaviour when focus moves elsewhere in the same key window.
    @MainActor
    public static func isSelectionEmphasized(in view: NSView?) -> Bool {
        guard NSApp.isActive, let window = view?.window, window.isKeyWindow else { return false }
        guard let container = view?.enclosingScrollView ?? view else { return false }
        guard let responder = window.firstResponder as? NSView else { return false }
        return responder === container || responder.isDescendant(of: container)
    }
}
#endif
