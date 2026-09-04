#if os(macOS)
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
    /// Set to enable inline rename on double-click. When nil, double-click has no effect.
    public var onRenameItem: ((Item, String) -> Void)?
    /// Lazily supplies an item's children, enabling arbitrary-depth expansion below the
    /// section level. Called on-demand by AppKit for each visible row (never a pre-scan of
    /// the whole tree). `nil` (the default) preserves today's flat two-level behavior exactly.
    public var childrenProvider: ((Item) -> [Item])?
    /// Whether an item should show a disclosure triangle at all. Only consulted when
    /// `childrenProvider` is also set.
    public var isExpandableProvider: ((Item) -> Bool)?
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
        var previousChildCounts: [Section: Int] = [:]
        let previousSections: Set<Section>
        let isFirstLoad = orderedSectionBoxes.isEmpty
        if !isFirstLoad {
            previousSections = Set(orderedSectionBoxes.map { $0.section })
            for box in orderedSectionBoxes where outlineView.isItemExpanded(box) {
                expandedSections.insert(box.section)
            }
            for box in orderedSectionBoxes {
                previousChildCounts[box.section] = itemsBySection[ObjectIdentifier(box)]?.count ?? 0
            }
        } else {
            previousSections = []
        }

        // Snapshot expanded item-level (tree) nodes by value identity, since ItemBox
        // instances are reused via itemBoxCache — see box(for:) — but a row's expanded
        // state in the live outline view is keyed by whichever box object is currently
        // visible at that row.
        var expandedItems: Set<Item> = []
        if childrenProvider != nil {
            for row in 0..<outlineView.numberOfRows {
                guard let box = outlineView.item(atRow: row) as? ItemBox,
                      outlineView.isItemExpanded(box) else { continue }
                expandedItems.insert(box.item)
            }
        }

        rebuildBoxes()
        outlineView.reloadData()

        for box in orderedSectionBoxes {
            // Expand if: first load, was already expanded, or is a newly appeared section.
            let isNew = !previousSections.contains(box.section)
            let gainedChildren = (previousChildCounts[box.section] ?? 0) == 0
                && (itemsBySection[ObjectIdentifier(box)]?.isEmpty == false)
            if isFirstLoad || expandedSections.contains(box.section) || isNew || gainedChildren {
                outlineView.expandItem(box)
            }
        }

        if !expandedItems.isEmpty {
            for sectionBox in orderedSectionBoxes {
                let sectionItems = itemsBySection[ObjectIdentifier(sectionBox)]?.map(\.item) ?? []
                restoreItemExpansion(items: sectionItems, expandedItems: expandedItems)
            }
        }

        if let prev = previouslySelected {
            isSuppressingSelectionCallbacks = true
            selectItem(where: { $0 == prev })
            isSuppressingSelectionCallbacks = false
        }
    }

    /// Recursively re-expands tree nodes that were expanded before a reload, walking only
    /// into subtrees that need it (never a full pre-scan of the whole tree).
    private func restoreItemExpansion(items: [Item], expandedItems: Set<Item>) {
        guard let childrenProvider else { return }
        for item in items {
            guard expandedItems.contains(item) else { continue }
            outlineView.expandItem(box(for: item))
            restoreItemExpansion(items: childrenProvider(item), expandedItems: expandedItems)
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

    /// Programmatically begins inline rename on the first item matching the predicate.
    /// No-op if `onRenameItem` is not set.
    public func beginRenaming(itemWhere predicate: (Item) -> Bool) {
        guard onRenameItem != nil else { return }
        for row in 0..<outlineView.numberOfRows {
            guard let box = outlineView.item(atRow: row) as? ItemBox,
                  predicate(box.item) else { continue }
            isSuppressingSelectionCallbacks = true
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            isSuppressingSelectionCallbacks = false
            outlineView.scrollRowToVisible(row)
            guard let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) as? SidebarCellView else { return }
            let item = box.item
            cell.beginRenaming(
                onCommit: { [weak self] newName in self?.onRenameItem?(item, newName) },
                onCancel: {}
            )
            return
        }
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
    // Persists across reloadData() calls (unlike orderedSectionBoxes/itemsBySection, which are
    // rebuilt fresh every time) so a tree node's box identity is stable — required for
    // NSOutlineView's own isItemExpanded/expandItem tracking, which is keyed by object identity,
    // to keep working across reloads for item-level (not just section-level) expansion.
    private var itemBoxCache: [Item: ItemBox] = [:]

    private final class SectionBox: NSObject {
        let section: Section
        init(_ section: Section) { self.section = section }
    }

    private final class ItemBox: NSObject {
        var item: Item
        init(_ item: Item) { self.item = item }
    }

    private func box(for item: Item) -> ItemBox {
        if let existing = itemBoxCache[item] {
            existing.item = item
            return existing
        }
        let box = ItemBox(item)
        itemBoxCache[item] = box
        return box
    }

    private func rebuildBoxes() {
        orderedSectionBoxes = sections.map { SectionBox($0) }
        itemsBySection = [:]
        for sectionBox in orderedSectionBoxes {
            let sectionItems = items.filter { $0.section == sectionBox.section }
            itemsBySection[ObjectIdentifier(sectionBox)] = sectionItems.map { box(for: $0) }
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
        outlineView.target = proxy
        outlineView.doubleAction = #selector(OutlineProxy.handleDoubleClick)

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
            if let box = item as? ItemBox {
                guard let childrenProvider, isExpandableProvider?(box.item) == true else { return 0 }
                return childrenProvider(box.item).count
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
            if let box = item as? ItemBox, let childrenProvider {
                let children = childrenProvider(box.item)
                return self.box(for: children[index])
            }
            return orderedSectionBoxes[0]
        }

        proxy.isItemExpandable = { [weak self] item in
            if item is SectionBox { return true }
            guard let self, let box = item as? ItemBox else { return false }
            return isExpandableProvider?(box.item) ?? false
        }
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

        proxy.doubleAction = { [weak self] in
            guard let self, onRenameItem != nil else { return }
            let row = outlineView.clickedRow
            guard row >= 0,
                  let box = outlineView.item(atRow: row) as? ItemBox,
                  let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SidebarCellView
            else { return }
            let item = box.item
            cell.beginRenaming(
                onCommit: { [weak self] newName in self?.onRenameItem?(item, newName) },
                onCancel: {}
            )
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

    // v1.4 Phase 4.3 (item 7): rebuilt on a plain NSStackView instead of a hand-toggled pair of
    // mutually exclusive trailing constraints for the title field (one for "count showing", one
    // for "no count"), flipped on every reuse depending on badgeText. A stack view's standard,
    // documented behaviour already does this for free: a hidden arranged subview (the count
    // field, when there's no badge) collapses its own space and the surrounding spacing
    // automatically, so the title field naturally extends to fill whatever's left — no manual
    // constraint bookkeeping needed at all.
    private func makeItemView(_ sidebarItem: Item) -> NSView {
        let id = NSUserInterfaceItemIdentifier("SidebarItemCell")
        let cell: SidebarCellView
        if let reused = outlineView.makeView(withIdentifier: id, owner: nil) as? SidebarCellView {
            cell = reused
        } else {
            cell = SidebarCellView()
            cell.identifier = id

            let icon = NSImageView()
            icon.imageScaling = .scaleNone
            icon.setContentHuggingPriority(.required, for: .horizontal)
            icon.setContentCompressionResistancePriority(.required, for: .horizontal)

            let titleField = NSTextField()
            titleField.isEditable = false
            titleField.isSelectable = false
            titleField.isBordered = false
            titleField.drawsBackground = false
            // Not scrollable at rest: a scrollable cell ignores byTruncatingTail and
            // hard-clips against the count badge. SidebarCellView enables scrolling
            // only for the duration of an inline rename.
            titleField.lineBreakMode = .byTruncatingTail
            // Low hugging/compression: the title is the one flexible element in the row,
            // expanding to fill available space and truncating under pressure, while the
            // icon and count stay at their natural (required) size either side of it.
            titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let countField = NSTextField(labelWithString: "")
            countField.font = .monospacedDigitSystemFont(
                ofSize: NSFont.smallSystemFontSize, weight: .regular)
            countField.textColor = .tertiaryLabelColor
            countField.alignment = .right
            countField.setContentHuggingPriority(.required, for: .horizontal)
            countField.setContentCompressionResistancePriority(.required, for: .horizontal)

            let stack = NSStackView(views: [icon, titleField, countField])
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.distribution = .fill
            stack.spacing = 4
            stack.setCustomSpacing(8, after: titleField)
            stack.translatesAutoresizingMaskIntoConstraints = false

            cell.addSubview(stack)
            cell.imageView = icon
            cell.textField = titleField
            cell.countField = countField

            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 22),
                icon.heightAnchor.constraint(equalToConstant: 22),

                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
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
        } else {
            cell.countField?.stringValue = ""
            cell.countField?.isHidden = true
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
    var doubleAction: (() -> Void)?

    @objc func handleDoubleClick() {
        doubleAction?()
    }

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
#endif
