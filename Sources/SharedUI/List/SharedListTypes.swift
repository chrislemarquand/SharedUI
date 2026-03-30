import AppKit

public struct SharedListColumnDefinition: Sendable, Hashable {
    public let id: String
    public let title: String
    public let defaultWidth: CGFloat
    public let minWidth: CGFloat
    public let defaultIsVisible: Bool
    public let isSortable: Bool

    public init(
        id: String,
        title: String,
        defaultWidth: CGFloat,
        minWidth: CGFloat,
        defaultIsVisible: Bool,
        isSortable: Bool
    ) {
        self.id = id
        self.title = title
        self.defaultWidth = defaultWidth
        self.minWidth = minWidth
        self.defaultIsVisible = defaultIsVisible
        self.isSortable = isSortable
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
    public let initialFitDefaultsKey: String

    public init(
        autosaveName: String,
        visibilityDefaultsKey: String,
        initialFitDefaultsKey: String
    ) {
        self.autosaveName = autosaveName
        self.visibilityDefaultsKey = visibilityDefaultsKey
        self.initialFitDefaultsKey = initialFitDefaultsKey
    }
}

