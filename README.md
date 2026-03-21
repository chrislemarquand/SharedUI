# SharedUI

Shared AppKit/SwiftUI component library for macOS apps in this suite. Provides the window shell, sidebar, gallery, inspector, Quick Look coordination, settings, toolbar, and menu infrastructure that every app in the family uses.

Both Ledger and Librarian subclass and extend these components. New apps should start here before building anything app-specific.

See [`docs/Integration.md`](docs/Integration.md) for adoption instructions and [`docs/Architecture.md`](docs/Architecture.md) for boundary rules.

---

## Modules

### Shell — `SplitView/`

**Entry point**: `ThreePaneSplitViewController`

Base class for the standard three-pane (sidebar | content | inspector) window. Handles outer/inner split layout, persisted pane widths, initial inspector visibility, coalesced pane state sync, inspector toggle animation with first-responder preservation, and the spacebar → Quick Look keyboard monitor.

Apps subclass this and supply three pane view controllers. All layout behaviour is automatic; apps wire `onPaneStateChanged` to update their model.

Key public API: `isSidebarCollapsed`, `isInspectorCollapsed`, `innerSplitView`, `installContentKeyboardMonitor(contentView:onSpace:)`, `schedulePaneStateSync()`, `toggleInspector(_:)`.

Standard metrics: 1300×800 window default, 1100×720 minimum, sidebar min 220pt, content min 300pt, inspector 260–600pt, initial content ratio 70%.

---

### Sidebar — `Sidebar/`

**Entry point**: `AppKitSidebarController<Section, Item>`

Generic, type-safe NSOutlineView-backed sidebar. Conform `Section` to `AppKitSidebarSectionType` and `Item` to `AppKitSidebarItemType`. Handles expand/collapse section memory, selection tracking, keyboard navigation, and optional context menus via `menuProvider`.

Key public API: `items`, `onSelectionChange`, `menuProvider`, `reloadData()`, `selectItem(where:)`, `clearSelection()`, `focusSidebar()`.

Items carry an optional `badgeText` for at-a-glance counts.

---

### Gallery — `Gallery/`

**Entry points**: `SharedGalleryCollectionView`, `SharedGalleryLayout`, `GalleryMetrics`

`SharedGalleryCollectionView` is an `NSCollectionView` subclass with keyboard navigation (arrows, Escape, Return), mouse handling (background click, modified clicks, double-click, context menus), and closure-based callbacks. `SharedGalleryLayout` is an `NSCollectionViewFlowLayout` subclass that computes adaptive column counts and tile sizes. `GalleryMetrics` is a configurable struct for insets, spacing, corner radius, and detail row height — apps pass a customised instance to the layout.

Key gallery config differences between apps: `allowsShiftExtendedMovement` (Ledger ignores; Librarian uses), `handlesActivateOnReturn`, `GalleryMetrics` defaults.

`PinchZoomAccumulator` provides threshold-based zoom step accumulation (0.14 default) for pinch gesture wiring.

---

### Inspector — `Inspector/`

Composable SwiftUI building blocks for read-only inspector panels. All sizing values are in `InspectorMetrics`.

| Component | Purpose |
|---|---|
| `InspectorHeaderView` | Title, optional subtitle, action buttons |
| `InspectorFieldRow` | Two-column label/value layout |
| `InspectorFieldLabel` | Caption-style secondary label |
| `InspectorSectionContainer` | Expandable disclosure group with accent header |
| `InspectorPreviewCard` | Image preview with loading state and overlay |
| `InspectorLocationMapView` | Static map snapshot via `MKMapSnapshotter` |
| `InspectorScrollModifier` | View modifier adding safe scroll insets (56pt top) |

---

### Quick Look — `QuickLook/`

**Entry point**: `QuickLookPanelCoordinator<SourceID: Hashable>`

Generic coordinator over app-defined source IDs. Sets `QLPreviewPanel.shared()` data source and delegate directly — does not use the responder chain protocol. Call `present(sourceItems:focusedItem:displayURLForSource:...)` to open the panel.

Features: URL-based display item filtering, arrow key navigation with configurable `moveSelection` handler, bidirectional selection sync, zoom animation support via `sourceFrameForSource`, initial panel sizing (72% width, 78% height of screen), and aspect-ratio-preserving resize locking.

The spacebar keyboard shortcut that opens Quick Look lives in `ThreePaneSplitViewController.installContentKeyboardMonitor`, not in this coordinator. See [Integration.md](docs/Integration.md#quick-look).

---

### Settings — `Settings/`

**Entry points**: `SettingsWindowController`, `SettingsGridViewController`

`SettingsWindowController` provides a 620pt-wide tab-based settings window. Apps instantiate it, add tabs, and call `showWindowAndActivate()`.

`SettingsGridViewController` is a base class for individual settings panes. Override `makeRows()` to define label/control pairs; call `rebuildGrid()` for dynamic updates. Factory helpers: `makeCategoryLabel()`, `makeDescriptionLabel()`, `makeActionButton()`, `makeCheckbox()`.

`InspectorFieldSettingsViewController` handles hierarchical section/field toggle UI with mixed-state checkboxes and `onToggleSection`/`onToggleField` callbacks.

---

### Toolbar — `Toolbar/`

**Entry points**: `WindowToolbarSetup`, `ToolbarItemFactory`, `ToolbarAppearanceAdapter`

`WindowToolbarSetup.configureWindowForToolbar(_:)` applies `.fullSizeContentView`, `.automatic` toolbar style, and title bar settings in one call. Must be called before window display to prevent a compositor flash on macOS 26+.

`ToolbarItemFactory` provides `makeSpinnerItem()`, `makeInspectorToggleItem()`, and `makeZoomItem()`.

`ToolbarAppearanceAdapter` fires a rebuild callback when the system appearance genuinely changes (light ↔ dark ↔ high contrast), deduplicating redundant calls.

---

### Menu — `Menu/`

**Entry points**: `MenuBuilders`, `ContextMenuSupport`, `AboutPanel`

`MenuBuilders.makeStandardAppMenu()` and `makeStandardWindowMenu()` build the standard macOS app and Window menus with SF Symbol icons.

`ContextMenuSupport.targetSelection(clickedIndex:selectedIndices:)` resolves right-click targets: clicking an unselected item produces a single-item selection; clicking a selected item produces the full ordered selection. `makeMenuItem(_:symbol:action:)` builds context menu items.

`AboutPanel.showAboutPanel(credits:)` displays a custom About dialog with hyperlinked credits, auto-extracting app name and version from the bundle.

---

### Workflow Sheets — `Workflow/`

**Entry point**: `WorkflowSheetContainer`

SwiftUI building blocks for multi-step workflow sheets: `WorkflowSheetContainer` (sheet chrome with title and info button), `WorkflowSheetTitleRow`, `WorkflowOptionGroup`, `WorkflowInlineMessageBanner` (multi-message inline banner), `WorkflowDetailsPopover` (scrollable monospaced details).

---

### Placeholder — `Placeholder/`

**Entry point**: `PlaceholderView`

Empty and loading state using `ContentUnavailableView`. Shows a symbol, title, and optional description or indeterminate progress bar. Respects the Reduce Motion accessibility setting.

---

### Utilities — `Utilities/`

| Utility | Purpose |
|---|---|
| `KeyCode` | Hardware-independent key code constants (Tab, Space, Escape, Return, arrows, numpad) |
| `MoveCommandDirection` | Directional enum for navigation callbacks (up, down, left, right) |
| `AppAnimation` | Standard duration (0.16s) and easing; returns `nil` when Reduce Motion is enabled |
| `ObserveEquatable` | Deduplicates consecutive equal values before calling `onChange` |
| `NSAlert+SheetOrModal` | `runSheetOrModal()` with callback and async/await variants; auto-selects sheet vs modal |
| `AppTheme` | Shared accent color as both `NSColor` and SwiftUI `Color` |
