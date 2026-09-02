#if os(macOS)
import AppKit

public enum SharedListColumnGroup: Sendable, Hashable {
    case builtIn
    case metadata
}

public struct SharedListColumnDefinition: Sendable, Hashable {
    public let id: String
    public let title: String
    public let defaultWidth: CGFloat
    public let minWidth: CGFloat
    public let defaultIsVisible: Bool
    public let isSortable: Bool
    public let isToggleable: Bool
    public let group: SharedListColumnGroup

    public init(
        id: String,
        title: String,
        defaultWidth: CGFloat,
        minWidth: CGFloat,
        defaultIsVisible: Bool,
        isSortable: Bool,
        isToggleable: Bool = true,
        group: SharedListColumnGroup = .metadata
    ) {
        self.id = id
        self.title = title
        self.defaultWidth = defaultWidth
        self.minWidth = minWidth
        self.defaultIsVisible = defaultIsVisible
        self.isSortable = isSortable
        self.isToggleable = isToggleable
        self.group = group
    }
}

public struct SharedListSelectionSnapshot: Sendable, Hashable {
    public let selectedRows: [Int]
    public let focusedRow: Int?

    public init(selectedRows: [Int], focusedRow: Int?) {
        self.selectedRows = selectedRows
        self.focusedRow = focusedRow
    }
}

public struct SharedListPersistenceConfig: Sendable, Hashable {
    public let autosaveName: String
    public let visibilityDefaultsKey: String

    public init(
        autosaveName: String,
        visibilityDefaultsKey: String
    ) {
        self.autosaveName = autosaveName
        self.visibilityDefaultsKey = visibilityDefaultsKey
    }
}

public struct SharedListLayoutConfig: Sendable, Hashable {
    public let primaryColumnID: String
    public let rowHeight: CGFloat
    public let hasHorizontalScroller: Bool
    public let lockedColumnIDs: Set<String>

    public init(
        primaryColumnID: String,
        rowHeight: CGFloat,
        hasHorizontalScroller: Bool = true,
        lockedColumnIDs: Set<String> = []
    ) {
        self.primaryColumnID = primaryColumnID
        self.rowHeight = rowHeight
        self.hasHorizontalScroller = hasHorizontalScroller
        self.lockedColumnIDs = lockedColumnIDs
    }
}
#endif
