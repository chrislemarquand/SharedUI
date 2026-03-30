import AppKit

@MainActor
public final class SharedGalleryCollectionView: NSCollectionView {
    public var onBackgroundClick: (() -> Void)?
    public var onMoveSelection: ((MoveCommandDirection, Bool) -> Void)?
    public var contextMenuProvider: ((IndexPath) -> NSMenu?)?
    public var onDoubleClick: ((IndexPath) -> Void)?
    public var onActivateSelection: (() -> Void)?

    /// Ledger currently ignores shift+arrow movement; Librarian uses it to extend selection.
    public var allowsShiftExtendedMovement: Bool = true
    public var handlesActivateOnReturn: Bool = true

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickedIndexPath = indexPathForItem(at: point)

        super.mouseDown(with: event)

        guard let indexPath = clickedIndexPath else {
            onBackgroundClick?()
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
