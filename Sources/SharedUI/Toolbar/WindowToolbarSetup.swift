import AppKit

/// Applies the standard window configuration required for a consistent
/// Liquid Glass toolbar appearance across all apps using SharedUI.
/// Call this once from viewWillAppear before the window becomes visible —
/// calling it later causes a brief compositor flash on macOS 26.
public func configureWindowForToolbar(_ window: NSWindow) {
    window.styleMask.insert(.fullSizeContentView)
    window.toolbarStyle = .automatic
    window.titlebarSeparatorStyle = .automatic
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
}
