import AppKit
import Foundation

@MainActor
public final class SharedBrowserListTableView: NSTableView {
    public var onBackgroundClick: (() -> Void)?
    public var onModifiedRowClick: ((Int, NSEvent.ModifierFlags) -> Void)?
    public var contextMenuProvider: ((Int) -> NSMenu?)?
    public var onActivateSelection: (() -> Void)?

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)

        if clickedRow == -1 {
            deselectAll(nil)
            onBackgroundClick?()
            return
        }

        let selectionModifiers = event.modifierFlags.intersection([.command, .shift])
        if !selectionModifiers.isEmpty {
            onModifiedRowClick?(clickedRow, selectionModifiers)
            return
        }

        if clickedRow >= 0 {
            super.mouseDown(with: event)
        }
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
}

