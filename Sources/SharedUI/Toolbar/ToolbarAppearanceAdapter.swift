#if os(macOS)
import AppKit

/// Observes a window's effective appearance and fires a rebuild closure when
/// it genuinely changes (light ↔ dark ↔ high-contrast).
///
/// NSToolbar creates item views once and does not automatically re-render them
/// for appearance changes. Rebuilding the toolbar on appearance change ensures
/// button images and tints are correct in the new appearance.
///
/// Usage:
///   // In viewDidAppear, guard against creating it twice:
///   if toolbarAppearanceAdapter == nil, let window = view.window {
///       toolbarAppearanceAdapter = ToolbarAppearanceAdapter(window: window) { [weak self] in
///           self?.rebuildToolbarForCurrentAppearance()
///       }
///   }
///
///   // In teardown:
///   toolbarAppearanceAdapter?.invalidate()
///   toolbarAppearanceAdapter = nil
@MainActor
public final class ToolbarAppearanceAdapter {
    private var observation: NSKeyValueObservation?
    private var lastAppearanceName: NSAppearance.Name?
    private let onChange: @MainActor () -> Void

    public init(window: NSWindow, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        lastAppearanceName = window.effectiveAppearance.name
        observation = window.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, change in
            let newName = change.newValue?.name
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let newName else { return }
                guard self.lastAppearanceName != newName else { return }
                self.lastAppearanceName = newName
                MainActor.assumeIsolated {
                    self.onChange()
                }
            }
        }
    }

    /// Cancels the observation. Call this when the owning view controller disappears.
    public func invalidate() {
        observation = nil
        lastAppearanceName = nil
    }
}
#endif
