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
    /// Guards the locked-column/order-restore moves in `configureList` so the move notification
    /// handler below can tell those apart from a genuine user drag and only persist the latter.
    private var isApplyingProgrammaticColumnChange = false
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
        // `sizeToFit()` is AppKit's own native "recompute column widths honoring each column's
        // resizingMask against the current frame" call — a full recompute each time, not a
        // delta against a remembered previous width, so unlike passive columnAutoresizingStyle
        // alone it can't inherit a bad baseline from this view's pre-layout zero-ish frame.
        // Non-primary columns (`.userResizingMask` only, no `.autoresizingMask`) are untouched
        // by it, same as the passive mechanism — a user's dragged width is never overridden.
        tableView.sizeToFit()
        updateListPresentationState(hasItems: tableView.numberOfRows > 0)
    }

    // v1.4 architecture-outcome review (2026-09-27, R1): installColumnChangeObservers()
    // was only ever called once, from configureList() during viewDidLoad — after a genuine
    // disappear/reappear cycle (this controller is reused, not reallocated, by its own
    // hosting container the same way BrowserContainerViewController's siblings are),
    // viewWillDisappear's teardown left columnChangeObservers empty for good, so column
    // resize/move persistence silently stopped working after the first time this view left
    // and came back. Reinstalling on reappearance matches the convention already established
    // elsewhere in this codebase for the identical reuse pattern.
    public override func viewWillAppear() {
        super.viewWillAppear()
        guard columnChangeObservers.isEmpty else { return }
        installColumnChangeObservers()
    }

    public override func viewWillDisappear() {
        super.viewWillDisappear()
        columnChangeObservers.forEach { NotificationCenter.default.removeObserver($0) }
        columnChangeObservers = []
    }

    public func reloadData() {
        tableView.reloadData()
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
        // v1.4 Phase 4.2 (native-first revision): no manual initial frame. Setting one here
        // (an old `NSRect(origin: .zero, size: scrollView.contentView.bounds.size)`, i.e.
        // near-zero — nothing has been through Auto Layout yet at this point in viewDidLoad)
        // gave AppKit's column-autoresize math a bogus zero-width baseline for its first real
        // delta computation once the clip view later resized this table view for real, which
        // dumped almost the *entire* window width onto the primary column on top of its own
        // default width — the exact "enormous Name column, has to scroll to see other columns"
        // bug this revision was supposed to fix. Autoresizing `.width` below is enough: the
        // enclosing NSClipView sizes this table view itself once the view hierarchy actually
        // lays out, the same as any standard NSTableView-in-NSScrollView setup.
        tableView.autoresizingMask = [.width]
        tableView.usesAutomaticRowHeights = false
        tableView.rowHeight = layoutConfig.rowHeight
        let headerView = SharedBrowserListHeaderView()
        headerView.lockedColumnIDs = layoutConfig.lockedColumnIDs
        tableView.headerView = headerView
        // v1.4 Phase 4.2 (native-first revision): let AppKit own column-width redistribution
        // instead of hand-computing it. The primary column already carries `.autoresizingMask`
        // in its resizingMask below (others don't) — with any non-`.noColumnAutoresizing` style,
        // that's sufficient for AppKit to give 100% of every resize delta to the primary column
        // automatically, synchronously, on every window/pane resize, with no custom code. This
        // is exactly Finder's own mechanism for anchoring its Name column. The previous
        // `.noColumnAutoresizing` + hand-rolled `fitTableToViewportIfNeeded()` (deleted) was
        // reimplementing this by hand, from view-lifecycle callbacks rather than actual resize
        // events — which is what produced both the years of "resize doesn't feel native"
        // complaints and a directly observed bug: the hand-rolled fit recomputing on every
        // `reloadData()` while rows loaded in caused the horizontal scrollbar to visibly
        // flicker on/off with the window completely static, as the vertical scroller's own
        // width claim shifted the computed viewport width across the fit's threshold.
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
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
                if definition.id != layoutConfig.primaryColumnID,
                   let width = columnStore.width(forColumnID: definition.id) {
                    column.width = width
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

    /// A persisted column order (`restorePersistedColumnOrder`, just above in `configureList`)
    /// can predate a locked column's existence, leaving it wherever that restore happened to
    /// slot it in (commonly the end) rather than adjacent to the primary column as intended.
    /// Locked columns have no drag-to-reorder affordance for the user to fix this themselves,
    /// so pin them back to immediately follow the primary column, in the order they're
    /// declared, every time.
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
        // `MainActor.assumeIsolated`, not `Task { @MainActor ... }`, is required here: a
        // `Task { @MainActor ... }` defers to a *later* run-loop turn, which broke the
        // equivalent guard this file used to need around a hand-rolled viewport-fit
        // computation (see git history / docs/v1.4-progress.md's Phase 4.2 detail) — that
        // computation is gone now (AppKit's own `.uniformColumnAutoresizingStyle` replaces it),
        // but the same synchronous-dispatch requirement still applies to
        // `isApplyingProgrammaticColumnChange` below, guarding the locked-column/order-restore
        // moves in `configureList`. `assumeIsolated` runs synchronously in the same call stack
        // — valid because `queue: .main` already guarantees this closure only fires on the main
        // thread.
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

    /// AppKit's native `.uniformColumnAutoresizingStyle` (see `configureList`) only ever
    /// resizes the primary column on a window/pane resize — a non-primary column's width only
    /// ever changes via a genuine user drag (`.userResizingMask`), so nothing here needs to
    /// guess at intent; simply persist every non-primary column's current width whenever any
    /// of them changes.
    private func handleColumnDidResize() {
        for column in tableView.tableColumns where column.identifier.rawValue != layoutConfig.primaryColumnID {
            columnStore.setWidth(column.width, forColumnID: column.identifier.rawValue)
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
        host?.sharedBrowserListColumnVisibilityDidChange(self, columnID: definition.id, isVisible: newVisible)
    }

    private func updateListPresentationState(hasItems: Bool) {
        tableView.usesAlternatingRowBackgroundColors = hasItems
        tableView.headerView?.isHidden = !hasItems
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
