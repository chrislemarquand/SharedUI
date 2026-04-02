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

    @MainActor
    public static func isSelectionEmphasized(in view: NSView?) -> Bool {
        NSApp.isActive && (view?.window?.isKeyWindow == true)
    }
}
