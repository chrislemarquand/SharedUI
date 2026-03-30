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
}

@MainActor
public final class SharedBrowserListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let tableView = SharedBrowserListTableView(frame: .zero)

    public weak var host: SharedBrowserListHosting?

    private let columns: [SharedListColumnDefinition]
    private let persistence: SharedListPersistenceConfig
    private var columnStore: SharedListColumnStore

    public init(
        columns: [SharedListColumnDefinition],
        persistence: SharedListPersistenceConfig
    ) {
        self.columns = columns
        self.persistence = persistence
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
    }

    public func reloadData() {
        tableView.reloadData()
    }

    private func configureList() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        tableView.translatesAutoresizingMaskIntoConstraints = true
        tableView.frame = NSRect(origin: .zero, size: scrollView.contentView.bounds.size)
        tableView.autoresizingMask = [.width]
        tableView.usesAutomaticRowHeights = false
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

        for definition in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(definition.id))
            column.title = definition.title
            column.minWidth = definition.minWidth
            column.width = definition.defaultWidth
            column.resizingMask = definition.id == columns.first?.id
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

        scrollView.documentView = tableView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        host?.sharedBrowserListSortDidChange(self, descriptor: tableView.sortDescriptors.first)
    }
}

