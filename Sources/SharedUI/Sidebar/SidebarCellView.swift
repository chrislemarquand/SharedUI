#if os(macOS)
import AppKit

// v1.4 Phase 4.3: this used to override backgroundStyle to force the icon's tint and the count
// field's colour on selection/emphasis/key-window changes, on the assumption AppKit's own
// propagation wasn't reliably reaching them. Confirmed live on macOS 27 (both apps) with the
// override fully removed: icons and count badges dim/brighten correctly with zero custom code —
// plain NSTableCellView/NSImageView/NSTextField backgroundStyle propagation already handles all
// of it. The only real custom behaviour left here is inline rename.
public final class SidebarCellView: NSTableCellView, NSTextFieldDelegate {

    var countField: NSTextField?

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
        // Scrollable only while editing so long names can scroll under the caret;
        // at rest the field must stay non-scrollable to truncate with an ellipsis.
        textField.cell?.isScrollable = true
        textField.delegate = self
        textField.selectText(nil)
    }

    private func finishRenaming(cancelled: Bool) {
        guard renameOnCommit != nil || renameOnCancel != nil else { return }
        guard let textField else { return }
        let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        textField.isEditable = false
        textField.isSelectable = false
        textField.cell?.isScrollable = false
        // Toggling isScrollable resets the cell's wrapping behaviour; restore truncation.
        textField.lineBreakMode = .byTruncatingTail
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
}
#endif
