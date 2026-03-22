import AppKit

/// Applies the native Liquid Glass toolbar presentation without forcing
/// additional titlebar overrides.
@MainActor
public func configureWindowForToolbar(_ window: NSWindow) {
    window.styleMask.insert(.fullSizeContentView)
    window.toolbarStyle = .automatic
}
