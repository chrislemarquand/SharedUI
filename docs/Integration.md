# SharedUI Integration Guide

How to wire up a new app using SharedUI, in the correct order. Covers the non-obvious parts — the obvious parts are readable from the source.

---

## 1. Package dependency

Add SharedUI as a local package dependency in the app's Xcode project. Use a local path reference, not a version pin, so both repos stay in lockstep.

---

## 2. Window shell

Subclass `ThreePaneSplitViewController` and supply the three pane view controllers in `init`:

```swift
super.init(
    sidebar: sidebarController,
    content: contentController,
    inspector: inspectorController,
    mainSplitAutosaveName: "\(AppBrand.identifierPrefix).MainSplit",
    contentSplitAutosaveName: "\(AppBrand.identifierPrefix).InnerSplit",
    inspectorStartsVisible: false   // or true — persisted after first session
)
```

Wire `onPaneStateChanged` to sync collapsed state back to your model and refresh the toolbar:

```swift
onPaneStateChanged = { [weak self] in
    guard let self else { return }
    self.model.isInspectorCollapsed = self.isInspectorCollapsed
    self.toolbarDelegate.refresh(model: self.model)
}
```

**Do not** call `schedulePaneStateSync()` directly unless you need to force a sync outside of split resize events. The base class calls it automatically on resize and visibility changes.

### Inspector toggle

`toggleInspector(_:)` is already implemented in the base class with animation and first-responder preservation. Wire it to the toolbar button and the menu item. No override needed unless you need to intercept the toggle.

### Keyboard

Call `installContentKeyboardMonitor(contentView:onSpace:)` from `viewDidLoad` to install the spacebar → Quick Look monitor. Pass the content pane's view and a closure that calls your Quick Look action. The monitor is removed automatically in `viewWillDisappear`.

```swift
installContentKeyboardMonitor(contentView: contentController.view) { [weak self] in
    guard let self, self.isContentViewActive else { return }
    self.quickLookSelectionAction(nil)
}
```

The guard inside the closure is where app-specific conditions go (e.g., only fire when the gallery is the active view, not the log pane). The monitor itself handles modal/sheet/key-window gating and the strict content-view focus check — do not duplicate those in the closure.

Any app-specific keyboard shortcuts that don't belong in the shared monitor (e.g., a custom ⌘⌃I inspector shortcut) should be installed as a separate `NSEvent.addLocalMonitorForEvents` and torn down explicitly in `viewWillDisappear`.

### Toolbar

Call `WindowToolbarSetup.configureWindowForToolbar(_:)` early in your toolbar delegate setup, before the window appears, to apply `.fullSizeContentView` and toolbar style. Calling it after the window is visible produces a compositor flash on macOS 26+.

For the toolbar delegate itself, conform to `ToolbarShellContent` (item identifiers + item construction) and hand it to a `ToolbarShellController` rather than implementing `NSToolbarDelegate` per app:

```swift
private lazy var toolbarShell = ToolbarShellController(content: self)
// in window setup, after WindowToolbarSetup.configureWindowForToolbar(_:):
toolbarShell.installToolbar(on: window, identifier: "MainToolbar")
```

Call `toolbarShell.syncAndValidate(window:)` whenever item enabled/selected state needs revalidating (e.g. after a selection change) rather than calling `window.toolbar?.validateVisibleItems()` directly.

---

## 3. Sidebar

Conform your section and item types to `AppKitSidebarSectionType` and `AppKitSidebarItemType`:

```swift
// Section requires: title
// Item requires: sectionID, title, symbolName; optional: badgeText
```

Instantiate `AppKitSidebarController<Section, Item>` and pass it as the `sidebar` pane. Wire selection changes:

```swift
sidebarController.onSelectionChange = { [weak self] item in
    self?.model.handleSidebarSelection(item)
}
```

To update badges, mutate `sidebarController.items` and call `reloadData()`. To programmatically select an item, use `selectItem(where:)`.

For context menus, assign `sidebarController.menuProvider`. The closure receives the item and returns an `NSMenu?`.

### Drag-to-reorder (opt-in)

Reordering and cross-section "promotion" (dragging an item so it becomes its own section) are both off by default via protocol extension defaults. To opt in, implement on your `Item` type:

```swift
var sidebarReorderID: String? { id }       // stable identity across reorders
var isSidebarReorderable: Bool { true }
var sidebarPromotionTargets: Set<Section> { [] }  // non-empty to allow promotion into these sections
```

Wire `onItemsReordered` (fires with the new full item order) and, if you allow promotion, `onItemPromotedToSection`. An item with `isSidebarReorderable == false` can still be dragged if it has non-empty `sidebarPromotionTargets` — the two capabilities are independent.

---

## 4. Path bar

Instantiate `PathBarViewController` and add its view (fixed height: `PathBarViewController.preferredHeight`, 32pt) above or below your browser content. Set `url` whenever the current folder changes; wire `onItemClicked` to navigate to the clicked breadcrumb segment's URL. Use `rootOverride` when the real filesystem root shouldn't be shown as-is (e.g. label an iCloud container's root with the container's display name instead of its raw path component).

---

## 5. List

Use `SharedBrowserListViewController` as (or embedded within) your list-mode browser view controller. Implement `SharedBrowserListHosting` to supply row data and respond to selection/sort changes — the controller owns the `NSTableView` itself (`tableView`, `scrollView` are both public if you need direct access).

Column definitions are plain `SharedListColumnDefinition` values (id, title, widths, sortability, toggleability, group); back visibility/order/width persistence with a `SharedListColumnStore`, which you initialise with your own storage read/write closures (typically thin wrappers around `UserDefaults`) — the store itself holds no persistence mechanism of its own.

For row drag-to-reorder, set `canReorderRows = true` and wire `onRowReordered`. For context menus, assign `contextMenuProvider`.

**Do not** assume column-change observers survive a hide/show cycle by accident — they don't need special handling from callers because the controller reinstalls them itself on `viewWillAppear` when needed, but if you're embedding `SharedBrowserListViewController` inside your own container that manages its lifecycle non-standardly (not through normal `NSViewController` containment appear/disappear), verify those callbacks still fire.

---

## 6. Gallery

Use `SharedGalleryCollectionView` as the collection view class (set in your view controller or xib). Wire closures before the view appears:

```swift
galleryView.onBackgroundClick = { [weak self] in self?.model.clearSelection() }
galleryView.onMoveSelection = { [weak self] direction in
    self?.model.moveSelectionInGallery(direction: direction, extendingSelection: false)
}
galleryView.onDoubleClick = { [weak self] index in self?.openItem(at: index) }
galleryView.contextMenuProvider = { [weak self] in self?.buildGalleryContextMenu() }
```

Create a `SharedGalleryLayout` with your `GalleryMetrics` and assign it to the collection view's layout. The layout computes column count and tile size adaptively from available width.

`PinchZoomAccumulator` should be held as a property and fed `NSMagnificationGestureRecognizer` delta values. It fires a `onStep` callback when the accumulated gesture crosses the threshold (0.14 by default):

```swift
private let zoomAccumulator = PinchZoomAccumulator { [weak self] step in
    step > 0 ? self?.model.increaseGalleryZoom() : self?.model.decreaseGalleryZoom()
}
```

---

## 7. Quick Look

The coordinator and the keyboard trigger are separate concerns.

**Keyboard trigger** is handled by `installContentKeyboardMonitor` in the shell (see §2). It calls your `onSpace` closure synchronously — no `DispatchQueue.main.async` wrapper. The synchronous call is intentional and load-bearing: it ensures the panel is open and key before the event is fully consumed, preventing double-trigger races if the materialization step is slow.

**Coordinator** is `QuickLookPanelCoordinator<YourSourceID>`, held as a property on your content controller:

```swift
private let quickLookCoordinator = QuickLookPanelCoordinator<String>()
```

Call `present(...)` when the action fires:

```swift
quickLookCoordinator.present(
    sourceItems: selectedIDs,
    focusedItem: primaryID,
    displayURLForSource: { [weak self] id in self?.resolveDisplayURL(for: id) },
    sourceFrameForSource: { [weak self] id in self?.sourceFrame(for: id) },
    onWillClose: { [weak self] in self?.cleanupQuickLookSession() }
)
```

`displayURLForSource` must return a local file URL. For PhotoKit-backed assets this means materialising the asset to a temp file before or during the closure call. If `displayURLForSource` returns `nil` for all items, the panel will not open.

The coordinator sets `QLPreviewPanel.shared().dataSource` and `.delegate` directly — it does not use the responder chain `acceptsPreviewPanelControl` / `beginPreviewPanelControl` protocol. This is intentional. Do not also implement those methods on your view controllers; it will create a conflict.

Arrow key navigation inside the open panel is handled by the coordinator via `previewPanel(_:handle:)`. Return `false` for any keys you don't handle (space, escape, etc.) and QL will use its default behaviour for those.

---

## 8. Settings

Create a `SettingsWindowController` and add tab items for each pane. Subclass `SettingsGridViewController` for each settings pane and override `makeRows()` to define the label/control grid:

```swift
override func makeRows() -> [NSGridRow] {
    [
        makeRow(label: makeCategoryLabel("Archive"), controls: []),
        makeRow(label: makeDescriptionLabel("Destination"), controls: [destinationField]),
        makeRow(label: NSView(), controls: [makeActionButton("Choose…", action: #selector(chooseDestination))]),
    ]
}
```

For inspector field visibility toggles, use `InspectorFieldSettingsViewController` with your section and field model. Wire `onToggleSection` and `onToggleField` to your persistence layer.

---

## 9. Context menus

Use `ContextMenuSupport.targetSelection(clickedIndex:selectedIndices:)` to resolve right-click targets before building the menu. This ensures that right-clicking an unselected item produces a single-item menu while right-clicking within a selection produces the full selection — matching Finder behaviour.

Use `ContextMenuSupport.makeMenuItem(_:symbol:action:)` for consistent item construction.

---

## 10. Notice bar

Hold a `NoticeBarState` on your model/controller and a `NoticeBar(state:)` view in your window chrome (typically above the content pane). Mutate the state object directly:

```swift
noticeBarState.message = "3 files failed to import."
noticeBarState.primaryAction = NoticeBarAction(title: "Review") { [weak self] in self?.showImportLog() }
noticeBarState.isVisible = true
noticeBar.syncVisibility(animated: true)
```

`syncVisibility` is not called automatically on every state mutation — call it explicitly after changing `isVisible` (or any field affecting layout) so the show/hide animation actually runs.

---

## 11. Window frame persistence

Instantiate one `WindowFramePersistenceController` per window you want to restore, giving it an autosave name unique to that window (include the app's bundle identifier prefix, matching the split-view autosave name convention in §2). It restores immediately in `init` (`window.setFrameUsingName`), falling back to `defaultContentSize` + centering when there's nothing to restore, then wires `window.setFrameAutosaveName` so AppKit itself persists future moves/resizes — there is no separate save call to wire, and don't add your own `windowDidMove`/`windowDidEndLiveResize` observers alongside it to do the same thing.

---

## Common mistakes

**Calling `DispatchQueue.main.async` around the Quick Look action in the spacebar handler.**
The monitor already runs on the main thread. Adding async dispatch creates a timing window between event consumption and panel open that enables double-trigger races, especially when the `displayURLForSource` closure does blocking I/O (e.g., PhotoKit materialisation). Call the action synchronously.

**Broadening the focus check in `shouldHandleBrowserKeyCommands` or the `onSpace` closure guard.**
The shared monitor already enforces a strict content-view subtree check. Adding fallbacks for `view.isDescendant(of: splitViewController.view)` or accepting nil/window first responders causes the shortcut to fire in contexts where it shouldn't — during text editing, while the sidebar has focus, or while no view is focused. The closure guard should only contain app-specific semantic conditions (e.g., "only when the gallery is the active view"), not structural focus conditions.

**Implementing `acceptsPreviewPanelControl` alongside `QuickLookPanelCoordinator`.**
The coordinator sets data source and delegate directly. If any view controller in the responder chain also returns `true` from `acceptsPreviewPanelControl`, macOS will call `endPreviewPanelControl` on it when the panel loses key status, which may nil out the coordinator's data source. Use only one control path.

**Calling `WindowToolbarSetup.configureWindowForToolbar` after the window is visible.**
This causes a visible compositor flash on macOS 26+. It must be called before the window's first appearance — wire it in `viewWillAppear` or your toolbar delegate's initial configure call.

**Installing the content keyboard monitor multiple times.**
`installContentKeyboardMonitor` calls `removeContentKeyboardMonitor()` internally before installing, so double-calling is safe. But do not also install a separate monitor that handles space — the two monitors will both see the event and the first one to consume it wins, which may not be the shared one.
