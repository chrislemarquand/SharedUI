import AppKit

// SidebarCellView owns icon and text colour for the selected row.
// AppKit calls backgroundStyle on this cell when the row transitions between
// .emphasized (selected+focused) and .normal (selected+unfocused or deselected),
// so intercepting here is the correct and reliable place to keep them in sync.
public final class SidebarCellView: NSTableCellView {
    private static let normalConfig = NSImage.SymbolConfiguration(textStyle: .body, scale: .small)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.labelColor]))
    private static let emphasizedConfig = NSImage.SymbolConfiguration(textStyle: .body, scale: .small)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white]))

    override public var backgroundStyle: NSView.BackgroundStyle {
        get { super.backgroundStyle }
        set {
            super.backgroundStyle = newValue
            let emphasized = newValue == .emphasized
            imageView?.symbolConfiguration = emphasized ? Self.emphasizedConfig : Self.normalConfig
            textField?.textColor = emphasized ? .white : .labelColor
        }
    }
}
