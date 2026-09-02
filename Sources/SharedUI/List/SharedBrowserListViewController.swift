#if os(macOS)
import AppKit
import Foundation

@MainActor
public protocol SharedBrowserListHosting: AnyObject {
    func numberOfRows(in controller: SharedBrowserListViewController) -> Int
    func sharedBrowserList(
        _ controller: SharedBrowserListViewController,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView?
    func sharedBrowserListSelectionDidChange(
        _ controller: SharedBrowserListViewController,
        selectedRows: IndexSet,
        focusedRow: Int?
    )
    func sharedBrowserListSortDidChange(
        _ controller: SharedBrowserListViewController,
        descriptor: NSSortDescriptor?
    )
    func sharedBrowserListColumnVisibilityDidChange(
        _ controller: SharedBrowserListViewController,
        columnID: String,
        isVisible: Bool
    )
}

public extension SharedBrowserListHosting {
    func sharedBrowserListColumnVisibilityDidChange(
        _: SharedBrowserListViewController,
        columnID _: String,
        isVisible _: Bool
    ) {}
}

@MainActor
public final class SharedBrowserListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let tableView = SharedBrowserListTableView(frame: .zero)

    public weak var host: SharedBrowserListHosting?

    private let columns: [SharedListColumnDefinition]
    private let persistence: SharedListPersistenceConfig
    private let layoutConfig: SharedListLayoutConfig
    private var columnStore: SharedListColumnStore
    private var isApplyingProgrammaticSort = false
    /// Guards every programmatic column order/width mutation (viewport fit, locked-column
    /// enforcement, persisted-order restore) so the resize/move notification handlers below
    /// can tell those apart from a genuine user drag and only persist the latter.
    private var isApplyingProgrammaticColumnChange = false
    /// The width each non-primary column *should* have absent a viewport constraint — the
    /// user's last real drag, or its default. `fitTableToViewportIfNeeded` always computes
    /// from this, never from a column's possibly-already-shrunk current `.width`, so a
    /// transient narrow viewport never permanently erases a wider desired width.
    private var desiredNonPrimaryWidths: [String: CGFloat] = [:]
    private var columnChangeObservers: [NSObjectProtocol] = []

    public var contextMenuProvider: ((Int) -> NSMenu?)?
    /// When true, rows can be reordered by dragging. `onRowReordered` is called with
    /// the source row index and the destination row index (after removal of the source row).
    public var canReorderRows: Bool = false
    public var onRowReordered: ((_ from: Int, _ to: Int) -> Void)?

    public init(
        columns: [SharedListColumnDefinition],
        persistence: SharedListPersistenceConfig,
        layoutConfig: SharedListLayoutConfig
    ) {
        self.columns = columns
        self.persistence = persistence
        self.layoutConfig = layoutConfig
        self.columnStore = SharedListColumnStore(
            visibleKey: persistence.visibilityDefaultsKey,
            autosaveName: persistence.autosaveName
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = NSView(frame: .zero)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureList()
        updateListPresentationState(hasItems: (host?.numberOfRows(in: self) ?? 0) > 0)
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        fitTableToViewportIfNeeded()
        updateListPresentationState(hasItems: tableView.numberOfRows > 0)
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        fitTableToViewportIfNeeded()
    }

    public override func viewWillDisappear() {
        super.viewWillDisappear()
        columnChangeObservers.forEach { NotificationCenter.default.removeObserver($0) }
        columnChangeObservers = []
    }

    public func reloadData() {
        tableView.reloadData()
        fitTableToViewportIfNeeded()
        updateListPresentationState(hasItems: tableView.numberOfRows > 0)
    }

    public func setSortDescriptor(_ descriptor: NSSortDescriptor?) {
        guard tableView.sortDescriptors.first != descriptor else { return }
        isApplyingProgrammaticSort = true
        if let descriptor {
            tableView.sortDescriptors = [descriptor]
        } else {
            tableView.sortDescriptors = []
        }
        isApplyingProgrammaticSort = false
    }

    public func refreshColumnHeaderMenu() {
        tableView.headerView?.menu = buildColumnHeaderMenu()
    }

    private func configureList() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = layoutConfig.hasHorizontalScroller
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        tableView.translatesAutoresizingMaskIntoConstraints = true
        tableView.frame = NSRect(origin: .zero, size: scrollView.contentView.bounds.size)
        tableView.autoresizingMask = [.width]
        tableView.usesAutomaticRowHeights = false
        tableView.rowHeight = layoutConfig.rowHeight
        let headerView = SharedBrowserListHeaderView()
        headerView.lockedColumnIDs = layoutConfig.lockedColumnIDs
        tableView.headerView = headerView
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.gridStyleMask = []
        tableView.backgroundColor = .clear
        tableView.style = .inset
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([Self.reorderPasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)

        tableView.contextMenuProvider = { [weak self] row in
            self?.contextMenuProvider?(row)
        }
        for definition in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(definition.id))
            column.title = definition.title
            column.minWidth = definition.minWidth
            column.width = definition.defaultWidth
            column.resizingMask = definition.id == layoutConfig.primaryColumnID
                ? [.autoresizingMask, .userResizingMask]
                : .userResizingMask
            if definition.isSortable {
                column.sortDescriptorPrototype = NSSortDescriptor(key: definition.id, ascending: true)
            }
            tableView.addTableColumn(column)
        }

        for definition in columns {
            if let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == definition.id }) {
                // Non-toggleable columns have no "Show/Hide" menu entry, so there's no legitimate
                // way for a persisted visibility set (written before this column existed) to have
                // ever recorded them — always show them rather than reading stale persisted state.
                column.isHidden = definition.isToggleable ? !columnStore.isVisible(definition) : false
                if definition.id != layoutConfig.primaryColumnID {
                    let width = columnStore.width(forColumnID: definition.id) ?? definition.defaultWidth
                    column.width = width
                    desiredNonPrimaryWidths[definition.id] = width
                }
            }
        }
        restorePersistedColumnOrder()
        enforceLockedColumnPositions()
        tableView.headerView?.menu = buildColumnHeaderMenu()
        installColumnChangeObservers()

        scrollView.documentView = tableView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// `autosaveTableColumns` restores column order from a persisted layout that predates a
    /// locked column's existence, which can leave it wherever AppKit happened to slot it in
    /// (commonly the end) rather than adjacent to the primary column as intended. Locked columns
    /// have no drag-to-reorder affordance for the user to fix this themselves, so pin them back
    /// to immediately follow the primary column, in the order they're declared, every time.
    private func enforceLockedColumnPositions() {
        guard !layoutConfig.lockedColumnIDs.isEmpty,
              let primaryIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == layoutConfig.primaryColumnID })
        else { return }

        isApplyingProgrammaticColumnChange = true
        defer { isApplyingProgrammaticColumnChange = false }

        var insertionIndex = primaryIndex + 1
        for definition in columns where layoutConfig.lockedColumnIDs.contains(definition.id) {
            guard let currentIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == definition.id }) else { continue }
            if currentIndex != insertionIndex {
                tableView.moveColumn(currentIndex, toColumn: insertionIndex)
            }
            insertionIndex += 1
        }
    }

    /// Restores column order from `columnStore`. Any column absent from a persisted order
    /// (added after that snapshot was taken) simply keeps its natural `columns`-array
    /// position — `enforceLockedColumnPositions()` runs immediately after this and will
    /// correct a locked column's position regardless of how order restore left it.
    private func restorePersistedColumnOrder() {
        guard let persistedOrder = columnStore.columnOrder() else { return }
        isApplyingProgrammaticColumnChange = true
        defer { isApplyingProgrammaticColumnChange = false }

        var targetIndex = 0
        for columnID in persistedOrder {
            guard let currentIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == columnID }) else { continue }
            if currentIndex != targetIndex {
                tableView.moveColumn(currentIndex, toColumn: targetIndex)
            }
            targetIndex += 1
        }
    }

    private func installColumnChangeObservers() {
        let center = NotificationCenter.default
        // `MainActor.assumeIsolated`, not `Task { @MainActor ... }`, is required here: the
        // guard these handlers check (`isApplyingProgrammaticColumnChange`) is only true for
        // the duration of the synchronous call that set it (e.g. fitTableToViewportIfNeeded,
        // which resets it via `defer` the instant that function returns). NSTableView posts
        // this notification synchronously the moment `.width`/`moveColumn` runs, still inside
        // that guarded call — but `Task { @MainActor ... }` defers to a *later* run-loop turn,
        // by which point the guard has already been reset, so it never actually caught a
        // programmatic change and instead persisted every viewport-driven fit as if it were
        // user intent (also observed as a ~10x slowdown in
        // testBrowserViewModeSwitching, from the resulting feedback loop). `assumeIsolated`
        // runs synchronously in the same call stack — valid because `queue: .main` already
        // guarantees this closure only ever fires on the main thread.
        columnChangeObservers.append(center.addObserver(
            forName: NSTableView.columnDidResizeNotification,
            object: tableView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleColumnDidResize()
            }
        })
        columnChangeObservers.append(center.addObserver(
            forName: NSTableView.columnDidMoveNotification,
            object: tableView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleColumnDidMove()
            }
        })
    }

    /// Only a genuine user drag reaches here — every programmatic width write (viewport fit,
    /// locked-column enforcement, order restore) sets `isApplyingProgrammaticColumnChange`
    /// first. This is what stops a transient, viewport-driven width from being mistaken for
    /// durable user intent (docs/window-list-resize-diagnosis-2026-07.md's core anti-pattern).
    private func handleColumnDidResize() {
        guard !isApplyingProgrammaticColumnChange else { return }
        for column in tableView.tableColumns where column.identifier.rawValue != layoutConfig.primaryColumnID {
            let columnID = column.identifier.rawValue
            guard desiredNonPrimaryWidths[columnID] != column.width else { continue }
            desiredNonPrimaryWidths[columnID] = column.width
            columnStore.setWidth(column.width, forColumnID: columnID)
        }
    }

    private func handleColumnDidMove() {
        guard !isApplyingProgrammaticColumnChange else { return }
        columnStore.setColumnOrder(tableView.tableColumns.map(\.identifier.rawValue))
    }

    private func buildColumnHeaderMenu() -> NSMenu {
        let menu = NSMenu()
        let builtInToggleable = columns.filter { $0.isToggleable && $0.group == .builtIn }
        let metadataToggleable = columns.filter { $0.isToggleable && $0.group == .metadata }

        for definition in builtInToggleable {
            menu.addItem(makeColumnMenuItem(for: definition))
        }
        if !builtInToggleable.isEmpty, !metadataToggleable.isEmpty {
            menu.addItem(.separator())
        }
        for definition in metadataToggleable {
            menu.addItem(makeColumnMenuItem(for: definition))
        }
        return menu
    }

    private func makeColumnMenuItem(for definition: SharedListColumnDefinition) -> NSMenuItem {
        let item = NSMenuItem(
            title: definition.title,
            action: #selector(toggleColumnFromHeader(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = definition.id
        let isVisible = tableView.tableColumns
            .first(where: { $0.identifier.rawValue == definition.id })
            .map { !$0.isHidden } ?? definition.defaultIsVisible
        item.state = isVisible ? .on : .off
        return item
    }

    @objc private func toggleColumnFromHeader(_ sender: NSMenuItem) {
        guard let columnID = sender.representedObject as? String,
              let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == columnID }),
              let definition = columns.first(where: { $0.id == columnID && $0.isToggleable })
        else { return }

        let newVisible = column.isHidden
        column.isHidden = !newVisible
        sender.state = newVisible ? .on : .off
        columnStore.setVisible(columnID, newVisible, allDefinitions: columns)
        adjustTableForColumnToggle()
        host?.sharedBrowserListColumnVisibilityDidChange(self, columnID: definition.id, isVisible: newVisible)
    }

    private func updateListPresentationState(hasItems: Bool) {
        tableView.usesAlternatingRowBackgroundColors = hasItems
        tableView.headerView?.isHidden = !hasItems
    }

    private func syncTableWidthToViewportIfNeeded() {
        let width = scrollView.contentView.bounds.width
        guard width > 0 else { return }
        if abs(tableView.frame.width - width) > 0.5 {
            var frame = tableView.frame
            frame.size.width = width
            tableView.frame = frame
        }
    }

    /// The single source of truth for column width on every layout pass — runs unconditionally
    /// (no one-shot gate), so a transient pre-window-restoration frame at launch has no lasting
    /// effect: the very next layout pass (once the real frame is known) simply recomputes
    /// correctly. Non-primary columns get their full desired width when there's room; when the
    /// viewport has shrunk since the desired widths were set, they're shrunk proportionally
    /// toward their minimums rather than left to overflow the table into horizontal scroll.
    /// Only genuinely insufficient space (even at every column's minimum) falls through to that
    /// overflow. All writes here are programmatic, not user intent — see
    /// `isApplyingProgrammaticColumnChange`.
    private func fitTableToViewportIfNeeded() {
        let viewportWidth = scrollView.contentView.bounds.width
        guard viewportWidth > 0 else { return }
        guard let primaryColumn = tableView.tableColumns.first(where: {
            $0.identifier.rawValue == layoutConfig.primaryColumnID
        }) else {
            syncTableWidthToViewportIfNeeded()
            return
        }

        let nonPrimary = tableView.tableColumns.filter {
            !$0.isHidden && $0.identifier.rawValue != layoutConfig.primaryColumnID
        }
        let desiredWidths = nonPrimary.map { desiredNonPrimaryWidths[$0.identifier.rawValue] ?? $0.width }
        let desiredOthersWidth = desiredWidths.reduce(0, +)
        let othersMinWidth = nonPrimary.reduce(0.0) { $0 + $1.minWidth }

        tableView.autoresizingMask = []
        isApplyingProgrammaticColumnChange = true
        defer { isApplyingProgrammaticColumnChange = false }

        var frame = tableView.frame
        if desiredOthersWidth + primaryColumn.minWidth <= viewportWidth {
            for (column, desired) in zip(nonPrimary, desiredWidths) { column.width = desired }
            primaryColumn.width = viewportWidth - desiredOthersWidth
            frame.size.width = floor(viewportWidth)
        } else if othersMinWidth + primaryColumn.minWidth <= viewportWidth {
            primaryColumn.width = primaryColumn.minWidth
            let available = viewportWidth - primaryColumn.minWidth
            let shrinkableTotal = desiredOthersWidth - othersMinWidth
            let excess = desiredOthersWidth - available
            for (column, desired) in zip(nonPrimary, desiredWidths) {
                let slack = desired - column.minWidth
                let share = shrinkableTotal > 0 ? slack / shrinkableTotal : 0
                column.width = desired - excess * share
            }
            frame.size.width = floor(viewportWidth)
        } else {
            primaryColumn.width = primaryColumn.minWidth
            for column in nonPrimary { column.width = column.minWidth }
            frame.size.width = ceil(othersMinWidth + primaryColumn.minWidth)
        }
        tableView.frame = frame
        tableView.tile()
    }

    private func adjustTableForColumnToggle() {
        fitTableToViewportIfNeeded()
    }

    public func numberOfRows(in _: NSTableView) -> Int {
        host?.numberOfRows(in: self) ?? 0
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        host?.sharedBrowserList(self, viewFor: tableColumn, row: row)
    }

    public func tableViewSelectionDidChange(_: Notification) {
        host?.sharedBrowserListSelectionDidChange(
            self,
            selectedRows: tableView.selectedRowIndexes,
            focusedRow: tableView.selectedRow >= 0 ? tableView.selectedRow : nil
        )
    }

    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard !isApplyingProgrammaticSort else { return }
        host?.sharedBrowserListSortDidChange(self, descriptor: tableView.sortDescriptors.first)
    }

    public func tableView(_ tableView: NSTableView, shouldSelect tableColumn: NSTableColumn?) -> Bool {
        guard let tableColumn else { return true }
        return !layoutConfig.lockedColumnIDs.contains(tableColumn.identifier.rawValue)
    }

    public func tableView(
        _ tableView: NSTableView,
        shouldReorderColumn columnIndex: Int,
        toColumn newColumnIndex: Int
    ) -> Bool {
        guard tableView.tableColumns.indices.contains(columnIndex) else { return false }
        let movingColumnID = tableView.tableColumns[columnIndex].identifier.rawValue
        if layoutConfig.lockedColumnIDs.contains(movingColumnID) {
            return false
        }

        let leadingLockedColumnCount = tableView.tableColumns.prefix {
            layoutConfig.lockedColumnIDs.contains($0.identifier.rawValue)
        }.count
        return newColumnIndex < 0 || newColumnIndex >= leadingLockedColumnCount
    }

    // MARK: - Row reorder (opt-in via canReorderRows)

    private static let reorderPasteboardType = NSPasteboard.PasteboardType("com.sharedui.list.reorder-row")

    public func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard canReorderRows else { return nil }
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: Self.reorderPasteboardType)
        return item
    }

    public func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation operation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard canReorderRows else { return [] }
        // Force all drops to land between rows (.above), never onto a row (.on).
        // Without this, releasing over a row centre proposes .on, validateDrop returns [],
        // and acceptDrop is never called.
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    public func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard canReorderRows,
              let sourceString = info.draggingPasteboard.string(forType: Self.reorderPasteboardType),
              let sourceRow = Int(sourceString)
        else { return false }

        // Destination row accounts for removal of the source row.
        let destRow = row > sourceRow ? row - 1 : row
        guard destRow != sourceRow else { return false }
        onRowReordered?(sourceRow, destRow)
        return true
    }
}
#endif
