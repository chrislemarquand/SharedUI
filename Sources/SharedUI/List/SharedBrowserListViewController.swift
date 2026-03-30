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
    private var isInColumnOverflow = false
    private var isApplyingProgrammaticSort = false

    public var contextMenuProvider: ((Int) -> NSMenu?)?
    public var onActivateSelection: (() -> Void)?

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
            initialFitKey: persistence.initialFitDefaultsKey
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
        syncTableWidthToViewportIfNeeded()
        applyInitialColumnFitIfNeeded()
        exitOverflowIfViewportFits()
        updateListPresentationState(hasItems: tableView.numberOfRows > 0)
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        syncTableWidthToViewportIfNeeded()
        applyInitialColumnFitIfNeeded()
    }

    public func reloadData() {
        tableView.reloadData()
        syncTableWidthToViewportIfNeeded()
        applyInitialColumnFitIfNeeded()
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
        tableView.headerView = NSTableHeaderView()
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.focusRingType = .none
        tableView.gridStyleMask = []
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self

        tableView.contextMenuProvider = { [weak self] row in
            self?.contextMenuProvider?(row)
        }
        tableView.onActivateSelection = { [weak self] in
            self?.onActivateSelection?()
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

        tableView.autosaveName = persistence.autosaveName
        tableView.autosaveTableColumns = true
        for definition in columns {
            if let column = tableView.tableColumns.first(where: { $0.identifier.rawValue == definition.id }) {
                column.isHidden = !columnStore.isVisible(definition)
            }
        }
        tableView.headerView?.menu = buildColumnHeaderMenu()

        scrollView.documentView = tableView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        guard !isInColumnOverflow else { return }
        let width = scrollView.contentView.bounds.width
        guard width > 0 else { return }
        if abs(tableView.frame.width - width) > 0.5 {
            var frame = tableView.frame
            frame.size.width = width
            tableView.frame = frame
        }
    }

    private func applyInitialColumnFitIfNeeded() {
        guard !columnStore.hasAppliedInitialFit else { return }
        guard let primaryColumn = tableView.tableColumns.first(where: {
            $0.identifier.rawValue == layoutConfig.primaryColumnID
        }) else { return }
        let viewportWidth = scrollView.contentView.bounds.width
        guard viewportWidth > 0 else { return }
        let visibleNonPrimary = tableView.tableColumns.filter {
            $0.identifier.rawValue != layoutConfig.primaryColumnID && !$0.isHidden
        }
        let fixedWidth = visibleNonPrimary.reduce(0.0) { $0 + $1.width }
        primaryColumn.width = max(primaryColumn.minWidth, floor(viewportWidth - fixedWidth))
        tableView.tile()
        columnStore.hasAppliedInitialFit = true
    }

    private func adjustTableForColumnToggle() {
        let viewportWidth = scrollView.contentView.bounds.width
        guard viewportWidth > 0 else { return }
        guard let primaryColumn = tableView.tableColumns.first(where: {
            $0.identifier.rawValue == layoutConfig.primaryColumnID
        }) else { return }
        let nonPrimary = tableView.tableColumns.filter {
            !$0.isHidden && $0.identifier.rawValue != layoutConfig.primaryColumnID
        }
        let othersWidth = nonPrimary.reduce(0.0) { $0 + $1.width }
        let minTotal = othersWidth + primaryColumn.minWidth

        if minTotal > viewportWidth {
            isInColumnOverflow = true
            tableView.autoresizingMask = []
            primaryColumn.width = primaryColumn.minWidth
            var frame = tableView.frame
            frame.size.width = ceil(minTotal)
            tableView.frame = frame
        } else {
            isInColumnOverflow = false
            tableView.autoresizingMask = [.width]
            primaryColumn.width = max(primaryColumn.minWidth, floor(viewportWidth - othersWidth))
            syncTableWidthToViewportIfNeeded()
        }
        tableView.tile()
    }

    private func exitOverflowIfViewportFits() {
        guard isInColumnOverflow else { return }
        let viewportWidth = scrollView.contentView.bounds.width
        guard viewportWidth > 0 else { return }
        guard let primaryColumn = tableView.tableColumns.first(where: {
            $0.identifier.rawValue == layoutConfig.primaryColumnID
        }) else { return }
        let nonPrimary = tableView.tableColumns.filter {
            !$0.isHidden && $0.identifier.rawValue != layoutConfig.primaryColumnID
        }
        let othersWidth = nonPrimary.reduce(0.0) { $0 + $1.width }
        guard othersWidth + primaryColumn.minWidth <= viewportWidth else { return }
        isInColumnOverflow = false
        tableView.autoresizingMask = [.width]
        primaryColumn.width = max(primaryColumn.minWidth, floor(viewportWidth - othersWidth))
        syncTableWidthToViewportIfNeeded()
        tableView.tile()
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
}
