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

    @MainActor
    public static func isSelectionEmphasized(in view: NSView?) -> Bool {
        NSApp.isActive && (view?.window?.isKeyWindow == true)
    }
}
