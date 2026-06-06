#if os(macOS)
import AppKit

@MainActor
public enum ToolbarItemFactory {
    public enum ZoomDirection {
        case zoomOut
        case zoomIn
    }

    public static func makeSpinnerItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        paletteLabel: String? = nil,
        containerSize: CGFloat = 16
    ) -> (item: NSToolbarItem, spinner: NSProgressIndicator) {
        let spinner = NSProgressIndicator(frame: .zero)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isDisplayedWhenStopped = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerSize, height: containerSize))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: containerSize),
            container.heightAnchor.constraint(equalToConstant: containerSize),
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = paletteLabel ?? label
        item.view = container
        item.isBordered = false
        item.visibilityPriority = .low
        return (item, spinner)
    }

    public static func makeInspectorToggleItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        paletteLabel: String = "Toggle Inspector",
        target: AnyObject? = nil,
        action: Selector,
        toolTip: String? = nil,
        accessibilityDescription: String = "Show or hide the inspector"
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = paletteLabel
        item.image = NSImage(systemSymbolName: "sidebar.trailing", accessibilityDescription: accessibilityDescription)
        item.target = target
        item.action = action
        item.toolTip = toolTip
        return item
    }

    public static func makeZoomItem(
        identifier: NSToolbarItem.Identifier,
        direction: ZoomDirection,
        target: AnyObject?,
        action: Selector,
        accessibilityDescription: String? = nil
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        switch direction {
        case .zoomOut:
            item.label = "Zoom Out"
            item.paletteLabel = "Zoom Out"
            item.image = NSImage(
                systemSymbolName: "minus",
                accessibilityDescription: accessibilityDescription ?? "Zoom out"
            )
            item.toolTip = "Zoom out"
        case .zoomIn:
            item.label = "Zoom In"
            item.paletteLabel = "Zoom In"
            item.image = NSImage(
                systemSymbolName: "plus",
                accessibilityDescription: accessibilityDescription ?? "Zoom in"
            )
            item.toolTip = "Zoom in"
        }
        item.autovalidates = false
        item.target = target
        item.action = action
        return item
    }
}
#endif
