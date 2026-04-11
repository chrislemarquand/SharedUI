import AppKit

// MARK: - Generic controller

public final class AppKitSidebarController<Section, Item>: NSViewController
where Section: AppKitSidebarSectionType, Item: AppKitSidebarItemType, Item.SectionType == Section {

    public enum InitialSelectionBehavior {
        case selectFirstItem
        case noInitialSelection
    }

    // MARK: - Public interface

    public var sections: [Section]
    public var items: [Item]
    public let initialSelectionBehavior: InitialSelectionBehavior

    public private(set) var selectedItem: Item?
    public var onSelectionChange: ((Item) -> Void)?
    public var menuProvider: ((Item) -> NSMenu?)?
    public var onItemsReordered: (([Item]) -> Void)?
    public var onItemPromotedToSection: ((Item, Section) -> Void)?

    public init(
        sections: [Section],
        items: [Item],
        initialSelectionBehavior: InitialSelectionBehavior = .selectFirstItem
    ) {
        self.sections = sections
        self.items = items
        self.initialSelectionBehavior = initialSelectionBehavior
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func reloadData() {
        let previouslySelected = selectedItem

        // Snapshot expanded state before boxing is rebuilt.
        // Empty on first call (viewDidLoad hasn't run yet) → treat as first load → expand all.
        var expandedSections: Set<Section> = []
        let previousSections: Set<Section>
        let isFirstLoad = orderedSectionBoxes.isEmpty
        if !isFirstLoad {
            previousSections = Set(orderedSectionBoxes.map { $0.section })
            for box in orderedSectionBoxes where outlineView.isItemExpanded(box) {
                expandedSections.insert(box.section)
            }
        } else {
            previousSections = []
        }

        rebuildBoxes()
        outlineView.reloadData()

        for box in orderedSectionBoxes {
            // Expand if: first load, was already expanded, or is a newly appeared section.
            let isNew = !previousSections.contains(box.section)
            if isFirstLoad || expandedSections.contains(box.section) || isNew {
                outlineView.expandItem(box)
            }
        }

        if let prev = previouslySelected {
            isSuppressingSelectionCallbacks = true
            selectItem(where: { $0 == prev })
            isSuppressingSelectionCallbacks = false
        }
    }

    public func selectItem(where predicate: (Item) -> Bool) {
        for row in 0..<outlineView.numberOfRows {
            guard let box = outlineView.item(atRow: row) as? ItemBox,
                  predicate(box.item) else { continue }
            isSuppressingSelectionCallbacks = true
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            isSuppressingSelectionCallbacks = false
            break
        }
    }

    public func clearSelection() {
        guard outlineView.allowsEmptySelection else { return }
        outlineView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
        selectedItem = nil
    }

    public func focusSidebar() {
        view.window?.makeFirstResponder(outlineView)
    }

    // MARK: - Private state

    private var outlineView: SidebarOutlineView!
    private var scrollView: NSScrollView!
    private let proxy = OutlineProxy()
    private let dragPasteboardType = NSPasteboard.PasteboardType("com.sharedui.sidebar.reorder-item")
    private var isSuppressingSelectionCallbacks = false
    private var didApplyInitialScrollPosition = false

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
        outlineView.allowsEmptySelection = initialSelectionBehavior == .noInitialSelection
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 16
        outlineView.rowSizeStyle = .default
        outlineView.focusRingType = .none
        outlineView.registerForDraggedTypes([dragPasteboardType])
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)

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

    override public func viewDidLayout() {
        super.viewDidLayout()
        applyInitialScrollPositionIfNeeded()
    }

    private func applyInitialScrollPositionIfNeeded() {
        guard !didApplyInitialScrollPosition else { return }
        // automaticallyAdjustsContentInsets applies a top inset (toolbar height) after
        // the initial layout pass but does not retroactively correct the clip view's
        // scroll origin. Without this, the content sits below its intended position
        // and snaps upward on the first user click. Scrolling to .zero once the inset
        // is non-zero pre-applies the correction.
        guard scrollView.contentInsets.top > 0 else { return }
        didApplyInitialScrollPosition = true
        scrollView.documentView?.scroll(.zero)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
        switch initialSelectionBehavior {
        case .selectFirstItem:
            if selectedItem == nil, let first = items.first {
                selectItem(where: { $0 == first })
            }
        case .noInitialSelection:
            clearSelection()
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
            guard row >= 0, let box = outlineView.item(atRow: row) as? ItemBox else {
                selectedItem = nil
                return
            }
            selectedItem = box.item
            guard !isSuppressingSelectionCallbacks else { return }
            onSelectionChange?(box.item)
        }

        proxy.pasteboardWriterForItem = { [weak self] item in
            guard let self, let box = item as? ItemBox else { return nil }
            let canDrag = box.item.isSidebarReorderable || !box.item.sidebarPromotionTargets.isEmpty
            guard canDrag, let reorderID = box.item.sidebarReorderID else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(reorderID, forType: self.dragPasteboardType)
            return pasteboardItem
        }

        proxy.validateDrop = { [weak self] info, proposedItem, proposedChildIndex in
            guard let self else { return [] }
            return self.validateDrop(info: info, proposedItem: proposedItem, proposedChildIndex: proposedChildIndex)
        }

        proxy.acceptDrop = { [weak self] info, item, childIndex in
            guard let self else { return false }
            return self.acceptDrop(info: info, proposedItem: item, childIndex: childIndex)
        }
    }

    private func draggedReorderID(from info: NSDraggingInfo) -> String? {
        info.draggingPasteboard.string(forType: dragPasteboardType)
    }

    private func validateDrop(info: NSDraggingInfo, proposedItem: Any?, proposedChildIndex: Int) -> NSDragOperation {
        guard proposedChildIndex != NSOutlineViewDropOnItemIndex else { return [] }
        guard let sectionBox = proposedItem as? SectionBox else { return [] }
        guard let reorderID = draggedReorderID(from: info) else { return [] }
        guard let movingItem = item(forReorderID: reorderID) else { return [] }

        if movingItem.section != sectionBox.section {
            guard onItemPromotedToSection != nil else { return [] }
            guard movingItem.sidebarPromotionTargets.contains(sectionBox.section) else { return [] }
            return .move
        }

        guard movingItem.isSidebarReorderable else { return [] }
        let sectionItems = items.filter { $0.section == sectionBox.section }
        let reorderableCount = sectionItems.filter(\.isSidebarReorderable).count
        return reorderableCount > 1 ? .move : []
    }

    private func acceptDrop(info: NSDraggingInfo, proposedItem: Any?, childIndex: Int) -> Bool {
        guard childIndex != NSOutlineViewDropOnItemIndex else { return false }
        guard let sectionBox = proposedItem as? SectionBox else { return false }
        guard let reorderID = draggedReorderID(from: info) else { return false }
        guard let movingItem = item(forReorderID: reorderID) else { return false }

        if movingItem.section != sectionBox.section {
            guard movingItem.sidebarPromotionTargets.contains(sectionBox.section) else { return false }
            onItemPromotedToSection?(movingItem, sectionBox.section)
            return true
        }

        guard movingItem.isSidebarReorderable else { return false }
        guard let reordered = reorderedItemsInSection(movingReorderID: reorderID, section: sectionBox.section, destinationSectionIndex: childIndex) else {
            return false
        }

        items = reordered
        reloadData()
        selectItem(where: { $0.sidebarReorderID == reorderID })
        onItemsReordered?(reordered)
        return true
    }

    private func item(forReorderID reorderID: String) -> Item? {
        items.first { $0.sidebarReorderID == reorderID }
    }

    private func reorderedItemsInSection(
        movingReorderID: String,
        section: Section,
        destinationSectionIndex: Int
    ) -> [Item]? {
        let sectionItems = items.filter { $0.section == section }
        guard !sectionItems.isEmpty else { return nil }

        let movingSectionIndex = sectionItems.firstIndex { $0.sidebarReorderID == movingReorderID }
        guard let movingSectionIndex else { return nil }
        let movingItem = sectionItems[movingSectionIndex]
        guard movingItem.isSidebarReorderable else { return nil }

        var reorderableItems = sectionItems.filter { $0.isSidebarReorderable && $0.sidebarReorderID != nil }
        guard reorderableItems.count > 1 else { return nil }
        guard let sourceReorderableIndex = reorderableItems.firstIndex(where: { $0.sidebarReorderID == movingReorderID }) else {
            return nil
        }

        let clampedSectionDestination = max(0, min(destinationSectionIndex, sectionItems.count))
        var destinationReorderableIndex = 0
        if clampedSectionDestination > 0 {
            for index in 0..<clampedSectionDestination {
                let item = sectionItems[index]
                if item.sidebarReorderID == movingReorderID {
                    continue
                }
                if item.isSidebarReorderable, item.sidebarReorderID != nil {
                    destinationReorderableIndex += 1
                }
            }
        }
        destinationReorderableIndex = max(0, min(destinationReorderableIndex, reorderableItems.count - 1))

        let movingReorderableItem = reorderableItems.remove(at: sourceReorderableIndex)
        reorderableItems.insert(movingReorderableItem, at: destinationReorderableIndex)

        var reorderableIterator = reorderableItems.makeIterator()
        let reorderedSectionItems = sectionItems.map { item -> Item in
            if item.isSidebarReorderable, item.sidebarReorderID != nil {
                return reorderableIterator.next() ?? item
            }
            return item
        }

        var groupedBySection = Dictionary(grouping: items, by: { $0.section })
        groupedBySection[section] = reorderedSectionItems

        var rebuilt: [Item] = []
        for orderedSection in sections {
            if let sectionItems = groupedBySection.removeValue(forKey: orderedSection) {
                rebuilt.append(contentsOf: sectionItems)
            }
        }
        for sectionItems in groupedBySection.values {
            rebuilt.append(contentsOf: sectionItems)
        }
        return rebuilt
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
    var pasteboardWriterForItem: ((Any) -> NSPasteboardWriting?)?
    var validateDrop: ((NSDraggingInfo, Any?, Int) -> NSDragOperation)?
    var acceptDrop: ((NSDraggingInfo, Any?, Int) -> Bool)?

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

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        pasteboardWriterForItem?(item)
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        validateDrop?(info, item, index) ?? []
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        acceptDrop?(info, item, index) ?? false
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
