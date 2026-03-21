import AppKit

@MainActor
public enum ContextMenuSupport {
    /// Resolves context-menu targets to match standard macOS behavior:
    /// - right-click on an unselected item targets only that item
    /// - right-click on a selected item targets the current ordered selection
    public static func targetSelection<ItemID: Hashable>(
        clicked: ItemID,
        selected: Set<ItemID>,
        orderedItems: [ItemID]
    ) -> [ItemID] {
        guard selected.contains(clicked) else {
            return [clicked]
        }
        return orderedItems.filter { selected.contains($0) }
    }

    public static func makeMenuItem(
        title: String,
        action: Selector,
        target: AnyObject?,
        symbolName: String,
        isEnabled: Bool
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.isEnabled = isEnabled
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return item
    }
}
