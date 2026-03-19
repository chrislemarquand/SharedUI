import AppKit

// The only custom behaviour needed beyond a plain NSTableCellView: when AppKit
// changes backgroundStyle (selected/deselected, emphasis, key-window transitions),
// set the icon colour to match. AppKit handles text field colours via super.
// Everything else — pill drawing, emphasis, focus — is native NSOutlineView behaviour.
public final class SidebarCellView: NSTableCellView {

    var countField: NSTextField?
    var titleTrailingToCount: NSLayoutConstraint?
    var titleTrailingToCell: NSLayoutConstraint?

    override public var backgroundStyle: NSView.BackgroundStyle {
        get { super.backgroundStyle }
        set {
            super.backgroundStyle = newValue
            imageView?.contentTintColor = newValue == .emphasized ? .white : .labelColor
            countField?.textColor = newValue == .emphasized ? .white : .tertiaryLabelColor
        }
    }
}
