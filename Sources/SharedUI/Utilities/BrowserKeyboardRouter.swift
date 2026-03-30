import AppKit

public enum BrowserKeyboardViewMode: Equatable {
    case list
    case gallery
}

public enum BrowserKeyboardCommand: Equatable {
    case passthrough
    case consume
    case togglePaneFocus
    case inspectorTab(backward: Bool)
    case zoomIn
    case zoomOut
    case clearSelection
    case selectAllFiltered
    case activateSelection
    case moveSelection(direction: MoveCommandDirection, extendingSelection: Bool)
    case extendSelectionToBoundary(towardStart: Bool)
}

public struct BrowserKeyboardInput {
    public var keyCode: UInt16
    public var characters: String?
    public var modifiers: NSEvent.ModifierFlags
    public var browserViewMode: BrowserKeyboardViewMode
    public var canIncreaseGalleryZoom: Bool
    public var canDecreaseGalleryZoom: Bool
    public var shouldHandlePaneTabSwitch: Bool
    public var shouldHandleInspectorTabCommands: Bool
    public var shouldHandleBrowserKeyCommands: Bool

    public init(
        keyCode: UInt16,
        characters: String?,
        modifiers: NSEvent.ModifierFlags,
        browserViewMode: BrowserKeyboardViewMode,
        canIncreaseGalleryZoom: Bool,
        canDecreaseGalleryZoom: Bool,
        shouldHandlePaneTabSwitch: Bool,
        shouldHandleInspectorTabCommands: Bool,
        shouldHandleBrowserKeyCommands: Bool
    ) {
        self.keyCode = keyCode
        self.characters = characters
        self.modifiers = modifiers
        self.browserViewMode = browserViewMode
        self.canIncreaseGalleryZoom = canIncreaseGalleryZoom
        self.canDecreaseGalleryZoom = canDecreaseGalleryZoom
        self.shouldHandlePaneTabSwitch = shouldHandlePaneTabSwitch
        self.shouldHandleInspectorTabCommands = shouldHandleInspectorTabCommands
        self.shouldHandleBrowserKeyCommands = shouldHandleBrowserKeyCommands
    }
}

public enum BrowserKeyboardRouter {
    public static func route(_ input: BrowserKeyboardInput) -> BrowserKeyboardCommand {
        let modifiers = input.modifiers.intersection([.command, .shift, .control, .option, .function])
        let isTabWithoutCommand = input.keyCode == KeyCode.tab && (modifiers.isEmpty || modifiers == [.shift])

        if isTabWithoutCommand && input.shouldHandlePaneTabSwitch {
            return .togglePaneFocus
        }

        if input.shouldHandleInspectorTabCommands && input.keyCode == KeyCode.tab {
            if modifiers.isEmpty {
                return .inspectorTab(backward: false)
            }
            if modifiers == [.shift] {
                return .inspectorTab(backward: true)
            }
        }

        if input.keyCode == KeyCode.equal || input.keyCode == KeyCode.numpadPlus {
            guard modifiers == [.command] || modifiers == [.command, .shift] else { return .passthrough }
            guard input.browserViewMode == .gallery else { return .consume }
            guard input.canIncreaseGalleryZoom else { return .consume }
            return .zoomIn
        }

        if input.keyCode == KeyCode.minus || input.keyCode == KeyCode.numpadMinus {
            guard modifiers == [.command] || modifiers == [.command, .shift] else { return .passthrough }
            guard input.browserViewMode == .gallery else { return .consume }
            guard input.canDecreaseGalleryZoom else { return .consume }
            return .zoomOut
        }

        guard input.shouldHandleBrowserKeyCommands else { return .passthrough }

        switch input.keyCode {
        case KeyCode.return, KeyCode.numpadReturn:
            guard modifiers.isEmpty else { return .passthrough }
            return .activateSelection
        case KeyCode.escape:
            guard modifiers.isEmpty else { return .passthrough }
            return .clearSelection
        case _ where input.characters == "a":
            guard modifiers == [.command] else { return .passthrough }
            return .selectAllFiltered
        case _ where input.characters == "d":
            guard modifiers == [.command] else { return .passthrough }
            return .clearSelection
        case KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.downArrow, KeyCode.upArrow:
            guard let direction = moveDirection(forKeyCode: input.keyCode) else { return .passthrough }
            if modifiers.isEmpty {
                if input.browserViewMode == .gallery {
                    return .moveSelection(direction: direction, extendingSelection: false)
                }
                if direction == .up || direction == .down {
                    return .moveSelection(direction: direction, extendingSelection: false)
                }
                return .passthrough
            }

            let isShiftOnly = modifiers == [.shift]
            let isCommandShift = modifiers == [.command, .shift]
            guard isShiftOnly || isCommandShift else { return .passthrough }

            if isCommandShift {
                let towardStart = direction == .left || direction == .up
                return .extendSelectionToBoundary(towardStart: towardStart)
            }
            return .moveSelection(direction: direction, extendingSelection: true)
        default:
            return .passthrough
        }
    }

    private static func moveDirection(forKeyCode keyCode: UInt16) -> MoveCommandDirection? {
        switch keyCode {
        case KeyCode.leftArrow: return .left
        case KeyCode.rightArrow: return .right
        case KeyCode.downArrow: return .down
        case KeyCode.upArrow: return .up
        default: return nil
        }
    }
}
