#if os(macOS)
import AppKit

@MainActor
public final class SharedGalleryCollectionView: NSCollectionView {
    public var onBackgroundClick: (() -> Void)?
    public var onMoveSelection: ((MoveCommandDirection, Bool) -> Void)?
    public var onModifiedItemClick: ((IndexPath, NSEvent.ModifierFlags) -> Void)?
    public var contextMenuProvider: ((IndexPath) -> NSMenu?)?
    public var onDoubleClick: ((IndexPath) -> Void)?
    public var onActivateSelection: (() -> Void)?
    public var onFirstResponderStatusChanged: (() -> Void)?

    /// Ledger currently ignores shift+arrow movement; Librarian uses it to extend selection.
    public var allowsShiftExtendedMovement: Bool = true
    public var handlesActivateOnReturn: Bool = true

    override public func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFirstResponderStatusChanged?() }
        return result
    }

    override public func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            // window.firstResponder still reports the outgoing responder (self) until this
            // method returns, so a synchronous callback here would see a stale "still focused"
            // state. Defer to the next runloop turn, by which point the window has already
            // installed the new first responder.
            DispatchQueue.main.async { [weak self] in
                self?.onFirstResponderStatusChanged?()
            }
        }
        return result
    }

    override public func mouseDown(with event: NSEvent) {
        // Unlike NSTableView, NSCollectionView does not promote itself to first responder
        // on click. Do it explicitly so selection emphasis (and keyboard navigation) follows
        // a plain click the same way it would for a table/outline row.
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }

        let point = convert(event.locationInWindow, from: nil)
        let clickedIndexPath = indexPathForItem(at: point)
        let hadSelectionBefore = !selectionIndexPaths.isEmpty

        // Intercept Shift+click and Cmd+click so the model can apply contiguous-range
        // vs toggle semantics. Plain clicks and rubber-band drags go through super normally.
        let selectionModifiers = event.modifierFlags.intersection([.shift, .command])
        if let indexPath = clickedIndexPath,
           !selectionModifiers.isEmpty,
           let onModifiedItemClick {
            onModifiedItemClick(indexPath, selectionModifiers)
            return
        }

        super.mouseDown(with: event)

        guard let indexPath = clickedIndexPath else {
            // Preserve AppKit-native drag/rubber-band selection. Only treat this as a
            // background clear when no items ended up selected after the interaction.
            if selectionIndexPaths.isEmpty {
                if hadSelectionBefore || event.clickCount == 1 {
                    onBackgroundClick?()
                }
            }
            return
        }

        if event.clickCount == 2 {
            onDoubleClick?(indexPath)
        }
    }

    override public func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection([.command, .control, .option, .function]).isEmpty,
           event.keyCode == KeyCode.escape {
            deselectAll(nil)
            onBackgroundClick?()
            return
        }

        if handlesActivateOnReturn,
           event.modifierFlags.intersection([.command, .control, .option, .shift, .function]).isEmpty,
           (event.keyCode == KeyCode.return || event.keyCode == KeyCode.numpadReturn) {
            onActivateSelection?()
            return
        }

        let movementModifiers = event.modifierFlags.intersection([.shift, .command, .control, .option, .function])
        if movementModifiers.subtracting([.shift]).isEmpty {
            let hasShift = movementModifiers.contains(.shift)
            if hasShift && !allowsShiftExtendedMovement {
                super.keyDown(with: event)
                return
            }
            let extendingSelection = hasShift

            let direction: MoveCommandDirection?
            switch event.keyCode {
            case KeyCode.leftArrow: direction = .left
            case KeyCode.rightArrow: direction = .right
            case KeyCode.downArrow: direction = .down
            case KeyCode.upArrow: direction = .up
            default: direction = nil
            }
            if let direction {
                onMoveSelection?(direction, extendingSelection)
                return
            }
        }

        super.keyDown(with: event)
    }

    override public func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let indexPath = indexPathForItem(at: point) else { return nil }
        return contextMenuProvider?(indexPath)
    }
}
#endif
