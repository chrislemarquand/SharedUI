# SharedUI Changelog

Contract-level changes: what callers need to know when updating. Not a feature log — focuses on API changes, behaviour changes, and integration requirements.

SharedUI has no independent release cadence — both consuming apps pin to the same local path and pick up changes as they're made (see `docs/Architecture.md`'s "Version discipline"). These version numbers exist only to give this changelog and `docs/Roadmap.md` a stable anchor to reference; they are tagged in git but not otherwise published or distributed.

---

## v1.1.0 — 2026-09-26

Consolidated entry covering everything since v1.0.3 (2026-03-21) — six months, 137 commits, no changelog entry written along the way. See `docs/Roadmap.md`'s "Completed" section for the detailed story behind several of these (particularly the macOS 27 chrome-workaround audit and the selection-highlight/sidebar-colour fixes). Going forward, add an entry here alongside any change a consumer needs to know about, rather than letting it accumulate again.

### Added

New modules:
- `PathBar/` — `PathBarViewController`, a display-only Finder-style breadcrumb bar (32pt fixed height).
- `List/` — `SharedBrowserListViewController` (generic `NSTableView`-backed browser list, via `SharedBrowserListHosting`), `SharedListColumnStore` (visibility/order/width persistence over app-supplied storage), `SharedListColumnDefinition`, `SharedListColumnGroup`, `SharedListSelectionSnapshot`.
- `NoticeBar/` — `NoticeBar`, `NoticeBarState`, `NoticeBarAction`: dismissible notice/info banner.
- `Welcome/` — `AppWelcomeViewController`, `AppWelcomePresentation`, `AppWelcomeFeature`: WhatsNewKit-based first-launch/what's-new sheet. New dependency: WhatsNewKit 2.2.1.
- `Window/` — `WindowFramePersistenceController`: window frame restore-and-persist in one call.
- `View/` — `AppearanceAwareView`: `NSView` firing a closure on effective-appearance change.
- `Toolbar/ToolbarShellController` — generic `NSToolbarDelegate`/`NSToolbarItemValidation` implementation over an app-supplied `ToolbarShellContent`, replacing per-app hand-written toolbar delegates.

New Gallery pieces: `SharedFilmstripLayout` (row-height-driven single-row layout, for a Finder-style Gallery view's filmstrip — not a drop-in replacement for `SharedGalleryLayout`'s column-count model), `GalleryOverlay`, `GalleryThumbnailSizing`, `GallerySelectionStyling`, `GallerySelectionAppearanceObserver`, `GalleryZoomTransitionSupport`, `LargePreviewCard`.

New Inspector pieces: `InspectorRatingFlagView` (star rating, pick/flag, colour label), `InspectorStatusSymbolRow`, `InspectorTextField` (with `.inspectorDidRequestFieldFocus` programmatic-focus notification), `InspectorPopupField`/`InspectorPopupOption`, `InspectorDatePickerField`, `InspectorTokenField`, `InspectorNSTokenField` (native `NSTokenField`-backed variant — Return-only tokenising, commas are valid inside values, deliberately not the separator), `TokenChip`, `TokenFlowLayout`, `InspectorPreviewActionControl`. `InspectorHeaderView` gained a `pendingChange: Bool` parameter (orange dot before the title).

New Utilities: `KeyboardShortcutSupport` (window-shortcut eligibility, editable-text/focus-containment checks, pane Tab-focus-cycling helpers), `MainActorCoalescer`, `ThumbnailGenerator` (oriented/QuickLook thumbnail generation, image-file detection, fallback icon, disk-cache staleness).

New Workflow piece: `WorkflowCityComboField` / `TimeZoneCityData` (city-name-to-timezone-identifier combo box).

Sidebar: opt-in drag-to-reorder and cross-section "promotion" — three new `AppKitSidebarItemType` protocol members with `false`/`nil`/`[]` defaults (`sidebarReorderID`, `isSidebarReorderable`, `sidebarPromotionTargets`), plus `onItemsReordered` and `onItemPromotedToSection` callbacks on `AppKitSidebarController`. Existing conformers are unaffected until they opt in.

`PathBarViewController` gained `rootOverride: (title: String, root: URL)?` — `NSPathControl` renders the real, nested `Mobile Documents/com~apple~CloudDocs` path with a duplicated "iCloud Drive" ancestor segment on some macOS versions; this lets the control build its normal real-hierarchy items first, then trims everything above a given root and relabels that item, keeping every item's real URL intact for click handling.

### Removed

- `ToolbarAppearanceAdapter` — deleted outright as dead code (zero callers since the `ToolbarShellController` refactor). If you still reference it, migrate to `ToolbarShellController`.
- `AppKitSidebarController`'s `ScrollContentInsetMode.manual(top:)` case, its public mode property, and `reapplyScrollContentInsetMode()` — deleted after confirming zero callers anywhere (macOS 27 chrome audit; see Roadmap.md item 1).
- `SidebarCellView`'s `backgroundStyle` override forcing icon/count-badge colour — deleted after confirming native `NSTableCellView`/`NSImageView`/`NSTextField` `backgroundStyle` propagation now handles icon, title, and count dimming correctly on its own (macOS 27 chrome audit; see Roadmap.md item 7 and the "Sidebar inactive-window label colour" entry).

### Fixed

- `SharedBrowserListViewController` reinstalls its column-resize/move-persistence observers on `viewWillAppear` when needed — previously installed only once from `configureList()`/`viewDidLoad`, so column width/order persistence silently stopped working after the view was hidden and shown again by its own hosting container.
- `GallerySelectionStyling.isSelectionEmphasized` is now first-responder-aware (checks actual content-pane focus), not just `NSApp.isActive && window.isKeyWindow` — a gallery/icon tile's selection previously stayed accent-coloured even after keyboard focus moved to the sidebar in the same key window, unlike List's native dimming behaviour. `SharedGalleryCollectionView.mouseDown` now explicitly calls `window?.makeFirstResponder(self)` to support this (`NSCollectionView` doesn't self-promote to first responder on click the way `NSTableView` does).
- `AppKitSidebarController.selectItem(where:)` now clears the current selection when nothing matches the predicate, instead of silently leaving the previously-selected row looking selected. Needed for a sidebar with ad hoc, not-always-visible entries (e.g. an item reached by drilling into a folder from the browser rather than clicking it in the sidebar itself) — the old behaviour left a stale, wrong row highlighted after navigating away from it.

### Integration notes

- `NoticeBar`'s `syncVisibility(animated:)` is not called automatically on state mutation — call it explicitly after changing `NoticeBarState`, or the show/hide animation won't run. See `Integration.md#10-notice-bar`.
- `WindowFramePersistenceController` both restores and wires ongoing autosave in `init` — don't add your own `windowDidMove`/`windowDidEndLiveResize` observers alongside it.
- Adopting `ToolbarShellController` replaces your app's own `NSToolbarDelegate` conformance; don't run both against the same window.
- Sidebar drag-to-reorder and promotion are independent capabilities — an item with `isSidebarReorderable == false` can still be draggable if `sidebarPromotionTargets` is non-empty.

---

## v1.0.3 — 2026-03-21

### Added
- `ThreePaneSplitViewController.installContentKeyboardMonitor(contentView:onSpace:)` — installs a spacebar → Quick Look keyboard monitor using the correct pattern (synchronous call, strict `contentView`-subtree focus guard, editable text view guard, modal/sheet/key-window gating). The monitor is removed automatically in `viewWillDisappear`. Callers should remove any app-side spacebar monitors that were duplicating this logic.
- `ContextMenuSupport` module — `targetSelection(clickedIndex:selectedIndices:)` for Finder-style right-click target resolution, and `makeMenuItem(_:symbol:action:)` for consistent context menu item construction.

### Integration notes
Apps previously handling the spacebar in an app-side `NSEvent.addLocalMonitorForEvents` monitor should migrate to `installContentKeyboardMonitor`. The common mistakes to avoid when doing so are documented in [Integration.md](Integration.md#common-mistakes).

---

## v1.0.2 — 2026-03-20

### Added
- `AboutPanel.showAboutPanel(credits:)` — custom About dialog with hyperlinked credits. Replaces per-app About implementations.
- `MenuBuilders.makeStandardAppMenu()` and `makeStandardWindowMenu()` — standard macOS App and Window menu construction with SF Symbol icons.

---

## v1.0.1 — 2026-03-19

### Added
- `AppKitSidebarController` — generic NSOutlineView-backed sidebar controller. Replaces per-app sidebar implementations. Requires conformance to `AppKitSidebarSectionType` and `AppKitSidebarItemType`.
- `ThreePaneSplitViewController` — base class for three-pane window shell. Apps migrate from direct `NSSplitViewController` subclassing. Required: call `super.init(sidebar:content:inspector:mainSplitAutosaveName:contentSplitAutosaveName:)` and wire `onPaneStateChanged`.
- `WindowToolbarSetup.configureWindowForToolbar(_:)` — must be called before window first appears to avoid compositor flash on macOS 26+.
- Inspector SwiftUI building blocks: `InspectorHeaderView`, `InspectorFieldRow`, `InspectorFieldLabel`, `InspectorSectionContainer`, `InspectorPreviewCard`, `InspectorLocationMapView`, `InspectorScrollModifier`.
- `SettingsWindowController`, `SettingsGridViewController`, `InspectorFieldSettingsViewController`.
- `SharedGalleryCollectionView`, `SharedGalleryLayout`, `GalleryMetrics`, `PinchZoomAccumulator`.
- `QuickLookPanelCoordinator<SourceID>` — generic Quick Look coordinator. Direct data source/delegate assignment; does not use responder chain protocol.
- `ToolbarItemFactory`, `ToolbarAppearanceAdapter`.
- `WorkflowSheetContainer` and sheet building blocks.
- `PlaceholderView`.
- Utilities: `KeyCode`, `MoveCommandDirection`, `AppAnimation`, `ObserveEquatable`, `NSAlert+SheetOrModal`, `AppTheme`.

---

## v1.0.0 — Initial extraction

Initial extraction from Ledger. Components stabilised during Librarian shell migration and confirmed working across both apps before being considered v1.0.0 baseline.
