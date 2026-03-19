import AppKit

// SidebarCellView ensures the icon always matches the text colour.
// AppKit manages text field colours via backgroundStyle. We read what AppKit
// set on the text field and mirror it to the image view in the same setter call —
// one moment, physically impossible to be different colours.
public final class SidebarCellView: NSTableCellView {

    var countField: NSTextField?
    var titleTrailingToCount: NSLayoutConstraint?
    var titleTrailingToCell: NSLayoutConstraint?

    override public var backgroundStyle: NSView.BackgroundStyle {
        get { super.backgroundStyle }
        set {
            super.backgroundStyle = newValue
            // Mirror AppKit's choice of title text colour directly to the icon.
            imageView?.contentTintColor = textField?.textColor
            // Count field is visually secondary except when on the accent pill.
            countField?.textColor = newValue == .emphasized ? textField?.textColor : .tertiaryLabelColor
        }
    }
}
