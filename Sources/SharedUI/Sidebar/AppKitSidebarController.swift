import AppKit

// MARK: - Generic controller

public final class AppKitSidebarController<Section, Item>: NSViewController
where Section: AppKitSidebarSectionType, Item: AppKitSidebarItemType, Item.SectionType == Section {

    // MARK: - Public interface

    public var sections: [Section]
    public var items: [Item]

    public private(set) var selectedItem: Item?
    public var onSelectionChange: ((Item) -> Void)?
    public var menuProvider: ((Item) -> NSMenu?)?

    public init(sections: [Section], items: [Item]) {
        self.sections = sections
        self.items = items
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func reloadData() {
        let previouslySelected = selectedItem

        // Snapshot expanded state before boxing is rebuilt.
        // Empty on first call (viewDidLoad hasn't run yet) → treat as first load → expand all.
        var expandedSections: Set<Section> = []
        let isFirstLoad = orderedSectionBoxes.isEmpty
        if !isFirstLoad {
            for box in orderedSectionBoxes where outlineView.isItemExpanded(box) {
                expandedSections.insert(box.section)
            }
        }

        rebuildBoxes()
        outlineView.reloadData()

        for box in orderedSectionBoxes {
            if isFirstLoad || expandedSections.contains(box.section) {
                outlineView.expandItem(box)
            }
        }

        if let prev = previouslySelected {
            selectItem(where: { $0 == prev })
        }
    }

    public func selectItem(where predicate: (Item) -> Bool) {
        for row in 0..<outlineView.numberOfRows {
            guard let box = outlineView.item(atRow: row) as? ItemBox,
                  predicate(box.item) else { continue }
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            break
        }
    }

    public func focusSidebar() {
        view.window?.makeFirstResponder(outlineView)
    }

    // MARK: - Private state

    private var outlineView: SidebarOutlineView!
    private var scrollView: NSScrollView!
    private let proxy = OutlineProxy()

    // Stable reference-type boxes so NSOutlineView gets consistent identity across calls.
    private var orderedSectionBoxes: [SectionBox] = []
    private var itemsBySection: [ObjectIdentifier: [ItemBox]] = [:]

    private final class SectionBox: NSObject {
        let section: Section
        init(_ section: Section) { self.section = section }
    }

    private final class ItemBox: NSObject {
        let item: Item
        init(_ item: Item) { self.item = item }
    }

    private func rebuildBoxes() {
        orderedSectionBoxes = sections.map { SectionBox($0) }
        itemsBySection = [:]
        for box in orderedSectionBoxes {
            let sectionItems = items.filter { $0.section == box.section }
            itemsBySection[ObjectIdentifier(box)] = sectionItems.map { ItemBox($0) }
        }
    }

    // MARK: - View lifecycle

    override public func loadView() {
        outlineView = SidebarOutlineView()
        outlineView.style = .sourceList
        outlineView.headerView = nil
        outlineView.floatsGroupRows = false
        outlineView.allowsEmptySelection = false
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 16
        outlineView.rowSizeStyle = .default
        outlineView.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.menuForClickedRow = { [weak self] row in
            guard let self, row >= 0,
                  let box = outlineView.item(atRow: row) as? ItemBox else { return nil }
            return menuProvider?(box.item)
        }

        wireProxy()
        outlineView.dataSource = proxy
        outlineView.delegate = proxy

        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        view = scrollView
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        if selectedItem == nil, let first = items.first {
            selectItem(where: { $0 == first })
        }
    }

    // MARK: - Proxy wiring
    // Swift cannot place @objc members in extensions of generic classes, so all
    // NSOutlineViewDataSource/Delegate calls are routed through a non-generic proxy.

    private func wireProxy() {
        proxy.numberOfChildrenOfItem = { [weak self] item in
            guard let self else { return 0 }
            if item == nil { return orderedSectionBoxes.count }
            if let box = item as? SectionBox {
                return itemsBySection[ObjectIdentifier(box)]?.count ?? 0
            }
            return 0
        }

        proxy.childAtIndex = { [weak self] (index, item) in
            guard let self else { return NSObject() }
            if item == nil { return orderedSectionBoxes[index] }
            if let box = item as? SectionBox,
               let children = itemsBySection[ObjectIdentifier(box)] {
                return children[index]
            }
            return orderedSectionBoxes[0]
        }

        proxy.isItemExpandable = { item in item is SectionBox }
        proxy.isGroupItem = { item in item is SectionBox }
        proxy.shouldSelectItem = { item in item is ItemBox }

        proxy.viewForItem = { [weak self] (_, item) in
            guard let self else { return nil }
            if let sectionBox = item as? SectionBox {
                return makeSectionHeaderView(title: sectionBox.section.title)
            }
            if let itemBox = item as? ItemBox {
                return makeItemView(itemBox.item)
            }
            return nil
        }

        proxy.selectionDidChange = { [weak self] _ in
            guard let self else { return }
            let row = outlineView.selectedRow
            guard row >= 0, let box = outlineView.item(atRow: row) as? ItemBox else { return }
            selectedItem = box.item
            onSelectionChange?(box.item)
        }
    }

    // MARK: - Cell factories

    private func makeSectionHeaderView(title: String) -> NSView {
        let id = NSUserInterfaceItemIdentifier("SidebarSectionCell")
        if let cell = outlineView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = title
            return cell
        }
        let cell = NSTableCellView()
        cell.identifier = id
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private func makeItemView(_ sidebarItem: Item) -> NSView {
        let id = NSUserInterfaceItemIdentifier("SidebarItemCell")
        let cell: SidebarCellView
        if let reused = outlineView.makeView(withIdentifier: id, owner: nil) as? SidebarCellView {
            cell = reused
        } else {
            cell = SidebarCellView()
            cell.identifier = id

            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.imageScaling = .scaleNone

            let titleField = NSTextField(labelWithString: "")
            titleField.translatesAutoresizingMaskIntoConstraints = false
            titleField.lineBreakMode = .byTruncatingTail

            let countField = NSTextField(labelWithString: "")
            countField.translatesAutoresizingMaskIntoConstraints = false
            countField.font = .monospacedDigitSystemFont(
                ofSize: NSFont.smallSystemFontSize, weight: .regular)
            countField.textColor = .tertiaryLabelColor
            countField.alignment = .right
            countField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            countField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

            cell.addSubview(icon)
            cell.addSubview(titleField)
            cell.addSubview(countField)
            cell.imageView = icon
            cell.textField = titleField
            cell.countField = countField

            // Two mutually exclusive trailing constraints for the title field:
            // • titleTrailingToCount — active when a count is shown; title stops before the count
            // • titleTrailingToCell  — active when no count; title can reach the cell edge
            let titleToCount = titleField.trailingAnchor.constraint(
                lessThanOrEqualTo: countField.leadingAnchor, constant: -4)
            let titleToCell = titleField.trailingAnchor.constraint(
                lessThanOrEqualTo: cell.trailingAnchor, constant: -8)
            cell.titleTrailingToCount = titleToCount
            cell.titleTrailingToCell = titleToCell

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 22),
                icon.heightAnchor.constraint(equalToConstant: 22),

                titleField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
                titleField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                titleToCell,     // active by default — no count on initial creation

                countField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                countField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = sidebarItem.title
        cell.imageView?.image = NSImage(
            systemSymbolName: sidebarItem.symbolName,
            accessibilityDescription: sidebarItem.title
        )

        if let text = sidebarItem.badgeText, !text.isEmpty {
            cell.countField?.stringValue = text
            cell.countField?.isHidden = false
            cell.titleTrailingToCount?.isActive = true
            cell.titleTrailingToCell?.isActive = false
        } else {
            cell.countField?.stringValue = ""
            cell.countField?.isHidden = true
            cell.titleTrailingToCount?.isActive = false
            cell.titleTrailingToCell?.isActive = true
        }

        return cell
    }
}

// MARK: - Non-generic outline proxy

// A plain NSObject subclass can conform to @objc protocols and be used as the
// data source / delegate for the outline view. All real logic is in closures
// that capture the generic controller's state.
final class OutlineProxy: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

    var numberOfChildrenOfItem: ((Any?) -> Int)?
    var childAtIndex: ((Int, Any?) -> Any)?
    var isItemExpandable: ((Any) -> Bool)?
    var isGroupItem: ((Any) -> Bool)?
    var shouldSelectItem: ((Any) -> Bool)?
    var viewForItem: ((NSTableColumn?, Any) -> NSView?)?
    var selectionDidChange: ((Notification) -> Void)?

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        numberOfChildrenOfItem?(item) ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        childAtIndex?(index, item) ?? NSObject()
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        isItemExpandable?(item) ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        isGroupItem?(item) ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        shouldSelectItem?(item) ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        viewForItem?(tableColumn, item)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        selectionDidChange?(notification)
    }
}

// MARK: - NSOutlineView subclass for per-row context menus

// Overrides menu(for:) to deliver right-click events to the controller's menuProvider
// without requiring @objc in a generic class extension.
final class SidebarOutlineView: NSOutlineView {
    var menuForClickedRow: ((Int) -> NSMenu?)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        return menuForClickedRow?(row) ?? super.menu(for: event)
    }
}
