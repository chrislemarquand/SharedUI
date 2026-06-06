#if os(macOS)
import AppKit

@MainActor
public protocol ToolbarShellContent: AnyObject {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem?
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool
    func syncToolbarState()
}

@MainActor
public extension ToolbarShellContent {
    func validateToolbarItem(_: NSToolbarItem) -> Bool { true }
    func syncToolbarState() {}
}

/// Shared toolbar host that centralises native NSToolbar install/validation flow,
/// while app code owns item construction and state rules via ToolbarShellContent.
@MainActor
public final class ToolbarShellController: NSObject, NSToolbarDelegate, NSToolbarItemValidation {
    private weak var content: ToolbarShellContent?

    public init(content: ToolbarShellContent) {
        self.content = content
    }

    public func setContent(_ content: ToolbarShellContent) {
        self.content = content
    }

    @discardableResult
    public func installToolbar(
        on window: NSWindow,
        identifier: String,
        displayMode: NSToolbar.DisplayMode = .iconOnly,
        allowsUserCustomization: Bool = false,
        autosavesConfiguration: Bool = false
    ) -> NSToolbar {
        let toolbar = NSToolbar(identifier: identifier)
        toolbar.delegate = self
        toolbar.displayMode = displayMode
        toolbar.allowsUserCustomization = allowsUserCustomization
        toolbar.autosavesConfiguration = autosavesConfiguration
        window.toolbar = toolbar
        return toolbar
    }

    public func syncAndValidate(window: NSWindow?) {
        content?.syncToolbarState()
        window?.toolbar?.validateVisibleItems()
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        content?.toolbarDefaultItemIdentifiers(toolbar) ?? []
    }

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        content?.toolbarAllowedItemIdentifiers(toolbar) ?? []
    }

    public func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        content?.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
    }

    public func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        content?.validateToolbarItem(item) ?? true
    }
}
#endif
