import AppKit

// SidebarSelectionRowView drives the three-state focus behaviour:
//   selected + focused   → .emphasized  (red pill, white text/icon via SidebarCellView)
//   selected + unfocused → .normal      (grey pill, labelColor text/icon)
//   not selected         → explicit colour set from isEmphasized (window active vs inactive)
public final class SidebarSelectionRowView: NSTableRowView {

    override public var isSelected: Bool {
        didSet { updateSubviewColors() }
    }

    override public var isEmphasized: Bool {
        didSet { updateSubviewColors() }
    }

    // Only tell cell views to use white text when the row is selected AND focused.
    // Unfocused-selected → .normal so text stays at labelColor over the grey pill.
    override public var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected && isEmphasized ? .emphasized : .normal
    }

    // Catch cells added to the row after initial layout (e.g. on first load).
    override public func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        updateSubviewColors()
    }

    private func updateSubviewColors() {
        // Selected rows: SidebarCellView.backgroundStyle fires when interiorBackgroundStyle
        // changes (.emphasized ↔ .normal), so the cell owns its own icon, text, and count colour.
        // Non-selected rows: backgroundStyle stays .normal regardless of emphasis, so
        // AppKit never fires it — we must set icon, text, and count explicitly here.
        guard !isSelected else { return }
        // isEmphasized is false both when the window is inactive AND when the window is
        // active but the sidebar doesn't have focus. We only want secondary colours in the
        // inactive-window case — when the window is active, items should always be labelColor
        // regardless of whether the sidebar is the first responder.
        let color: NSColor = window?.isKeyWindow == true ? .labelColor : .secondaryLabelColor
        let config = NSImage.SymbolConfiguration(textStyle: .body, scale: .small)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        for subview in subviews {
            guard let cell = subview as? NSTableCellView else { continue }
            cell.imageView?.symbolConfiguration = config
            cell.textField?.textColor = color
            (cell as? SidebarCellView)?.countField?.textColor = color
        }
    }
}
