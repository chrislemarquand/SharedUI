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

---

## 4. Gallery

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

## 5. Quick Look

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

## 6. Settings

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

## 7. Context menus

Use `ContextMenuSupport.targetSelection(clickedIndex:selectedIndices:)` to resolve right-click targets before building the menu. This ensures that right-clicking an unselected item produces a single-item menu while right-clicking within a selection produces the full selection — matching Finder behaviour.

Use `ContextMenuSupport.makeMenuItem(_:symbol:action:)` for consistent item construction.

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
