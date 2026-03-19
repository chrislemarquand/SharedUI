import AppKit

// SidebarSelectionRowView drives the three-state focus behaviour:
//   selected + focused   → .emphasized  (red pill, white text/icon via SidebarCellView)
//   selected + unfocused → .normal      (grey pill, labelColor text/icon)
//   not selected         → labelColor when window active, secondaryLabelColor when inactive
public final class SidebarSelectionRowView: NSTableRowView {

    override public var isSelected: Bool {
        didSet { updateSubviewColors() }
    }

    override public var isEmphasized: Bool {
        didSet { updateSubviewColors() }
    }

    override public var interiorBackgroundStyle: NSView.BackgroundStyle {
        isSelected && isEmphasized ? .emphasized : .normal
    }

    override public func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        updateSubviewColors()
    }

    private func updateSubviewColors() {
        // Selected rows: SidebarCellView.backgroundStyle fires when interiorBackgroundStyle
        // changes (.emphasized ↔ .normal), so the cell owns icon and text colour there.
        guard !isSelected else { return }

        // Non-selected rows: backgroundStyle stays .normal regardless of emphasis so
        // AppKit never re-fires it for these rows — set colours explicitly here.
        //
        // Use window.isKeyWindow (not isEmphasized) so items stay at labelColor whenever
        // the window is active, regardless of which pane has focus. secondaryLabelColor
        // is reserved for the window-inactive state only.
        //
        // contentTintColor is used for the icon (not symbolConfiguration) because
        // it is a direct NSImageView property that AppKit's backgroundStyle processing
        // does not touch, avoiding any ordering conflict with the text field path.
        let color: NSColor = window?.isKeyWindow == true ? .labelColor : .secondaryLabelColor
        for subview in subviews {
            guard let cell = subview as? NSTableCellView else { continue }
            cell.imageView?.contentTintColor = color
            cell.textField?.textColor = color
            (cell as? SidebarCellView)?.countField?.textColor = color
        }
    }
}
