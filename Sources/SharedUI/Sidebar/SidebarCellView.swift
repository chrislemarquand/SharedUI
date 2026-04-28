import AppKit

// The only custom behaviour needed beyond a plain NSTableCellView: when AppKit
// changes backgroundStyle (selected/deselected, emphasis, key-window transitions),
// set the icon colour to match. AppKit handles text field colours via super.
// Everything else — pill drawing, emphasis, focus — is native NSOutlineView behaviour.
public final class SidebarCellView: NSTableCellView, NSTextFieldDelegate {

    var countField: NSTextField?
    var titleTrailingToCount: NSLayoutConstraint?
    var titleTrailingToCell: NSLayoutConstraint?

    // MARK: - Inline rename

    private var renameOnCommit: ((String) -> Void)?
    private var renameOnCancel: (() -> Void)?
    private var renameOriginalValue: String = ""

    func beginRenaming(onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        guard let textField else { return }
        renameOnCommit = onCommit
        renameOnCancel = onCancel
        renameOriginalValue = textField.stringValue
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = self
        textField.selectText(nil)
    }

    private func finishRenaming(cancelled: Bool) {
        guard renameOnCommit != nil || renameOnCancel != nil else { return }
        guard let textField else { return }
        let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        textField.isEditable = false
        textField.isSelectable = false
        textField.delegate = nil
        if cancelled || value.isEmpty {
            textField.stringValue = renameOriginalValue
            let cb = renameOnCancel
            renameOnCommit = nil
            renameOnCancel = nil
            cb?()
        } else {
            let cb = renameOnCommit
            renameOnCommit = nil
            renameOnCancel = nil
            cb?(value)
        }
    }

    public func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finishRenaming(cancelled: true)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishRenaming(cancelled: false)
            return true
        }
        return false
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
        finishRenaming(cancelled: false)
    }

    // MARK: - Background style

    override public var backgroundStyle: NSView.BackgroundStyle {
        get { super.backgroundStyle }
        set {
            super.backgroundStyle = newValue
            let color: NSColor = newValue == .emphasized ? .white : .labelColor
            imageView?.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .body, scale: .small)
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            countField?.textColor = newValue == .emphasized ? .white : .tertiaryLabelColor
        }
    }
}
