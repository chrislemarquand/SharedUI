import AppKit
import Foundation

@MainActor
public final class SharedBrowserListTableView: NSTableView {
    public var contextMenuProvider: ((Int) -> NSMenu?)?

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        guard clickedRow >= 0 else { return nil }
        return contextMenuProvider?(clickedRow)
    }
}
