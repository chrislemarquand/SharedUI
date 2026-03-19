import AppKit

// SidebarSelectionRowView drives the selection pill appearance and keeps the
// icon in sync with the text colour for non-selected rows.
//
//   selected + focused   → interiorBackgroundStyle = .emphasized
//                          SidebarCellView.backgroundStyle mirrors white to icon
//   selected + unfocused → interiorBackgroundStyle = .normal
//                          SidebarCellView.backgroundStyle mirrors labelColor to icon
//   not selected         → backgroundStyle stays .normal; AppKit and vibrancy handle
//                          text colour — updateSubviewColors mirrors it to the icon
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
        // changes and mirrors the text colour to the icon in the same call — nothing to do.
        guard !isSelected else { return }

        // Non-selected rows: backgroundStyle stays .normal regardless of focus changes
        // so AppKit does not re-fire it for these rows. Mirror whatever colour AppKit
        // last put on the title text field to the icon — no colour decisions here.
        for subview in subviews {
            guard let cell = subview as? SidebarCellView else { continue }
            cell.imageView?.contentTintColor = cell.textField?.textColor
        }
    }
}
