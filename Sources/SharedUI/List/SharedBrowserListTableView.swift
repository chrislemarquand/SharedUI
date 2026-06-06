#if os(macOS)
import AppKit
import Foundation

@MainActor
public final class SharedBrowserListTableView: NSTableView {
    public var contextMenuProvider: ((Int) -> NSMenu?)?
    public var onActivateSelection: (() -> Void)?

    public override var style: NSTableView.Style {
        get { .inset }
        set { super.style = .inset }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        guard clickedRow >= 0 else { return nil }
        return contextMenuProvider?(clickedRow)
    }

    public override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control, .option, .shift, .function]).isEmpty else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == KeyCode.return || event.keyCode == KeyCode.numpadReturn {
            onActivateSelection?()
            return
        }

        super.keyDown(with: event)
    }

    public override func insertNewline(_ sender: Any?) {
        onActivateSelection?()
    }

    public override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        onActivateSelection?()
    }
}

@MainActor
final class SharedBrowserListHeaderView: NSTableHeaderView {
    var lockedColumnIDs: Set<String> = []

    override func mouseDown(with event: NSEvent) {
        guard !isLockedColumnEvent(event) else { return }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard !isLockedColumnEvent(event) else { return }
        super.rightMouseDown(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard !isLockedColumnEvent(event) else { return }
        super.otherMouseDown(with: event)
    }

    private func isLockedColumnEvent(_ event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        let columnIndex = column(at: point)
        guard columnIndex >= 0,
              let tableView,
              tableView.tableColumns.indices.contains(columnIndex)
        else { return false }
        let columnID = tableView.tableColumns[columnIndex].identifier.rawValue
        return lockedColumnIDs.contains(columnID)
    }
}
#endif
