#if os(macOS)
import Foundation

/// Shared list column persistence used by host apps.
///
/// v1.4 Phase 4.2: this store now owns column order and per-column widths itself,
/// rather than deferring to `NSTableView.autosaveTableColumns` — that mechanism has no
/// way to distinguish a genuine user drag from a transient, viewport-driven programmatic
/// width write, so every layout pass was silently overwriting "the user's saved width"
/// with whatever the current window size happened to produce (see
/// docs/window-list-resize-diagnosis-2026-07.md). `SharedBrowserListViewController` now
/// guards its own programmatic writes and only calls into this store from a real
/// `NSTableViewColumnDidResizeNotification`/`NSTableViewColumnDidMoveNotification` that
/// wasn't caused by that guard.
public struct SharedListColumnStore {
    private let defaults: UserDefaults
    private let visibleKey: String
    private let orderKey: String
    private let widthsKey: String

    public init(
        defaults: UserDefaults = .standard,
        visibleKey: String,
        autosaveName: String
    ) {
        self.defaults = defaults
        self.visibleKey = visibleKey
        self.orderKey = "\(autosaveName).columnOrder"
        self.widthsKey = "\(autosaveName).columnWidths"
    }

    public func isVisible(_ definition: SharedListColumnDefinition) -> Bool {
        guard let raw = defaults.array(forKey: visibleKey) as? [String] else {
            return definition.defaultIsVisible
        }
        return Set(raw).contains(definition.id)
    }

    public func setVisible(_ columnID: String, _ visible: Bool, allDefinitions: [SharedListColumnDefinition]) {
        var currentVisible = Set(defaults.array(forKey: visibleKey) as? [String] ?? allDefinitions
            .filter(\.defaultIsVisible)
            .map(\.id))
        if visible {
            currentVisible.insert(columnID)
        } else {
            currentVisible.remove(columnID)
        }
        defaults.set(Array(currentVisible), forKey: visibleKey)
    }

    public func columnOrder() -> [String]? {
        defaults.array(forKey: orderKey) as? [String]
    }

    public func setColumnOrder(_ order: [String]) {
        defaults.set(order, forKey: orderKey)
    }

    public func width(forColumnID columnID: String) -> CGFloat? {
        guard let widths = defaults.dictionary(forKey: widthsKey) as? [String: Double],
              let width = widths[columnID]
        else { return nil }
        return CGFloat(width)
    }

    public func setWidth(_ width: CGFloat, forColumnID columnID: String) {
        var widths = defaults.dictionary(forKey: widthsKey) as? [String: Double] ?? [:]
        widths[columnID] = Double(width)
        defaults.set(widths, forKey: widthsKey)
    }
}
#endif
