# SharedUI

Shared AppKit/SwiftUI component library for macOS apps in this suite. Provides the window shell, sidebar, path bar, browser list and gallery, inspector, Quick Look coordination, settings, toolbar, window persistence, and menu infrastructure that every app in the family uses.

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

Generic, type-safe NSOutlineView-backed sidebar. Conform `Section` to `AppKitSidebarSectionType` and `Item` to `AppKitSidebarItemType`. Handles expand/collapse section memory, selection tracking, keyboard navigation, drag-to-reorder (per-item, policy-gated), and optional context menus via `menuProvider`.

Key public API: `items`, `onSelectionChange`, `menuProvider`, `onItemsReordered`, `onItemPromotedToSection`, `onRenameItem`, `reloadData()`, `selectItem(where:)`, `clearSelection()`, `focusSidebar()`.

Items carry an optional `badgeText` for at-a-glance counts.

---

### Path Bar — `PathBar/`

**Entry point**: `PathBarViewController`

Finder-style breadcrumb bar for the current folder location, display-only, fixed `preferredHeight` of 32pt. Set `url` to update the displayed path; `onItemClicked` fires with the URL of whichever breadcrumb segment was clicked. `rootOverride` lets an app relabel the leftmost segment (e.g. an iCloud Drive container showing its own display name instead of a raw path component).

---

### List — `List/`

**Entry point**: `SharedBrowserListViewController`

`NSTableView`-backed browser list view, generic over a `SharedBrowserListHosting` delegate that supplies rows and responds to selection/sort/reorder. Owns column visibility, order, and width persistence via `SharedListColumnStore` (backed by app-supplied storage — typically `UserDefaults`), reinstalling its column-change observers across every real appear/disappear cycle so persistence doesn't silently stop working after the view is hidden and shown again.

Column definitions (`SharedListColumnDefinition`) describe id, title, default/min width, sortability, toggleability, and a `SharedListColumnGroup`. `canReorderRows` + `onRowReordered` support drag-to-reorder rows when the app enables it. `contextMenuProvider` builds per-row context menus.

---

### Gallery — `Gallery/`

**Entry points**: `SharedGalleryCollectionView`, `SharedGalleryLayout`, `SharedFilmstripLayout`, `GalleryMetrics`

`SharedGalleryCollectionView` is an `NSCollectionView` subclass with keyboard navigation (arrows, Escape, Return), mouse handling (background click, modified clicks, double-click, context menus), and closure-based callbacks. `SharedGalleryLayout` is an `NSCollectionViewFlowLayout` subclass that computes adaptive column counts and tile sizes from container width. `SharedFilmstripLayout` is the row-height-driven sibling for a single horizontally-scrolling filmstrip (as used by a Finder-style Gallery view) — a different sizing knob from `SharedGalleryLayout`'s column count, not a drop-in replacement. `GalleryMetrics` is a configurable struct (`.default` preset) for insets, spacing, corner radius, and detail row height — apps pass a customised instance to whichever layout they use.

Supporting pieces:

| Component | Purpose |
|---|---|
| `GalleryMetrics` | Insets, spacing, corner radius, detail row height (`.default` preset) |
| `GalleryOverlay` | Positions a corner badge (cloud state, pending-edit dot, etc.) onto a thumbnail image view |
| `GalleryThumbnailSizing` | Aspect-ratio-aware fitted sizing so overlays land on the actual visible (letterboxed) image, not the tile's full square |
| `GallerySelectionStyling` | Resolves the correct selection background color/CGColor for a tile, first-responder-aware |
| `GallerySelectionAppearanceObserver` | Repaints a custom `CALayer`-drawn selection on window key/app-active changes (`NSCollectionViewItem` has no native `backgroundStyle` propagation) |
| `GalleryZoomTransitionSupport` | Captures/restores scroll position across a pinch-zoom column-count change |
| `PinchZoomAccumulator` | Threshold-based zoom step accumulation (0.14 default) for pinch gesture wiring |
| `LargePreviewCard` | Flexible-size sibling of `InspectorPreviewCard` for a large primary preview pane (e.g. a Gallery view's big-image half) |

Key gallery config differences between apps: `allowsShiftExtendedMovement` (Ledger ignores; Librarian uses), `handlesActivateOnReturn`, `GalleryMetrics` defaults.

---

### Inspector — `Inspector/`

Composable SwiftUI (and a few AppKit-backed) building blocks for inspector panels. All sizing values are in `InspectorMetrics`.

| Component | Purpose |
|---|---|
| `InspectorHeaderView` | Title, optional subtitle, action buttons, orange pending-change dot |
| `InspectorFieldRow` | Two-column label/value layout |
| `InspectorFieldLabel` | Caption-style secondary label |
| `InspectorSectionContainer` | Expandable disclosure group with accent header |
| `InspectorPreviewCard` | Image preview with loading state and overlay |
| `InspectorPreviewActionControl` | Hover/press-aware action control overlaid on a preview |
| `InspectorLocationMapView` | Static map snapshot via `MKMapSnapshotter` |
| `InspectorScrollModifier` | View modifier adding safe scroll insets (56pt top) |
| `InspectorRatingFlagView` | Star rating (0–5), three-way pick/flag cycle, and colour label menu |
| `InspectorStatusSymbolRow` | Row of small status SF Symbols with accessibility labels/tooltips |
| `InspectorTextField` | Text field supporting programmatic focus via `.inspectorDidRequestFieldFocus` notification |
| `InspectorPopupField` | Labelled popup/dropdown over `InspectorPopupOption` values |
| `InspectorDatePickerField` | `NSDatePicker` wrapped for SwiftUI, with min/max date and element/style configuration |
| `InspectorTokenField` | SwiftUI-native chip-style token field |
| `InspectorNSTokenField` | `NSTokenField`-backed alternative for contexts needing native chip display and `NSVisualEffectView` appearance (Return-only tokenising; commas are valid inside values) |
| `TokenChip` / `TokenFlowLayout` | Shared rendering/layout primitives behind the token field variants |

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

**Entry points**: `WindowToolbarSetup`, `ToolbarShellController`, `ToolbarItemFactory`

`WindowToolbarSetup.configureWindowForToolbar(_:)` applies `.fullSizeContentView`, `.automatic` toolbar style, and title bar settings in one call. Must be called before window display to prevent a compositor flash on macOS 26+.

`ToolbarShellController` is a generic `NSToolbarDelegate`/`NSToolbarItemValidation` implementation, given an app-supplied `ToolbarShellContent` conformer that provides item identifiers and builds items on demand. Apps call `installToolbar(...)` once and `syncAndValidate(window:)` whenever toolbar state needs revalidating, instead of each app hand-rolling its own toolbar delegate.

`ToolbarItemFactory` provides `makeSpinnerItem()`, `makeInspectorToggleItem()`, and `makeZoomItem()`.

---

### Window — `Window/`

**Entry point**: `WindowFramePersistenceController`

Persists and restores a window's frame (and, where wired, split/column state) across launches. Apps instantiate one per window and let it own the autosave name.

---

### Menu — `Menu/`

**Entry points**: `MenuBuilders`, `ContextMenuSupport`, `AboutPanel`

`MenuBuilders.makeStandardAppMenu()` and `makeStandardWindowMenu()` build the standard macOS app and Window menus with SF Symbol icons.

`ContextMenuSupport.targetSelection(clickedIndex:selectedIndices:)` resolves right-click targets: clicking an unselected item produces a single-item selection; clicking a selected item produces the full ordered selection. `makeMenuItem(_:symbol:action:)` builds context menu items.

`AboutPanel.showAboutPanel(credits:)` displays a custom About dialog with hyperlinked credits, auto-extracting app name and version from the bundle.

---

### Notice Bar — `NoticeBar/`

**Entry point**: `NoticeBar`

`NSView`-based dismissible notice/info banner with a message, up to two actions, and an `NSObject`-based `NoticeBarState` apps mutate to drive visibility (`isVisible`, `message`, `primaryAction`/`secondaryAction`). Call `syncVisibility(animated:)` after changing state. Used for things like an "unsaved edits" or "archive needs attention" banner.

---

### Welcome — `Welcome/`

**Entry point**: `AppWelcomeViewController` (built on WhatsNewKit)

First-launch / "What's New" sheet. Apps supply an `AppWelcomePresentation` (app name, an ordered `[AppWelcomeFeature]` list, button titles/actions). Ledger dropped this feature in v1.4 (see `docs/CHANGELOG.md`); Librarian still uses it, which is why it remains in SharedUI.

---

### Workflow Sheets — `Workflow/`

**Entry point**: `WorkflowSheetContainer`

SwiftUI building blocks for multi-step workflow sheets: `WorkflowSheetContainer` (sheet chrome with title and info button), `WorkflowSheetTitleRow`, `WorkflowOptionGroup`, `WorkflowInlineMessageBanner` (multi-message inline banner), `WorkflowDetailsPopover` (scrollable monospaced details), `WorkflowCityComboField` (city-name-to-timezone-identifier combo box, backed by `TimeZoneCityData`).

---

### Placeholder — `Placeholder/`

**Entry point**: `PlaceholderView`

Empty and loading state using `ContentUnavailableView`. Shows a symbol, title, and optional description or indeterminate progress bar. Respects the Reduce Motion accessibility setting.

---

### View — `View/`

**Entry point**: `AppearanceAwareView`

`NSView` subclass firing `onEffectiveAppearanceChange` on `viewDidChangeEffectiveAppearance()` — for content that needs to react to a light/dark/appearance change but isn't otherwise observing it (e.g. a `CALayer`-drawn custom view).

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
| `KeyboardShortcutSupport` | Window-shortcut eligibility (`canHandleWindowShortcuts`), editable-text/focus-containment checks, and pane Tab-focus-cycling helpers (`shouldHandlePaneTabSwitch`, `togglePaneFocus`) |
| `MainActorCoalescer` | Coalesces repeated work requests into a single deferred `@MainActor` call per run loop turn |
| `ThumbnailGenerator` | Oriented/QuickLook-based thumbnail generation, image-file detection, fallback icon, and disk-cache staleness check |
