import AppKit

// SidebarCellView owns icon and text colour for the selected row.
// AppKit calls backgroundStyle when interiorBackgroundStyle changes
// (.emphasized ↔ .normal) on the row view.
//
// Icon colour uses contentTintColor — a direct NSImageView property
// unaffected by AppKit's backgroundStyle machinery (which only processes
// text fields). symbolConfiguration is kept purely for size/scale.
public final class SidebarCellView: NSTableCellView {

    var countField: NSTextField?
    var titleTrailingToCount: NSLayoutConstraint?
    var titleTrailingToCell: NSLayoutConstraint?

    override public var backgroundStyle: NSView.BackgroundStyle {
        get { super.backgroundStyle }
        set {
            super.backgroundStyle = newValue
            let emphasized = newValue == .emphasized
            imageView?.contentTintColor = emphasized ? .white : .labelColor
            textField?.textColor      = emphasized ? .white : .labelColor
            countField?.textColor     = emphasized ? .white : .labelColor
        }
    }
}
