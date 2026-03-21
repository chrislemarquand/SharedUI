# SharedUI Changelog

Contract-level changes: what callers need to know when updating. Not a feature log — focuses on API changes, behaviour changes, and integration requirements.

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
