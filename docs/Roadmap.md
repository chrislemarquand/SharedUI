# SharedUI Roadmap

Cross-repo work tracked here when it is clearly SharedUI-scoped, regardless of which app is driving it. Items sourced from Ledger and Librarian roadmaps are noted.

---

## In progress / near-term

### Gallery detail row toggle
Shared `showsGalleryDetailRow` setting exposed through each app's View menu.

- Default: `true` in Ledger, `false` in Librarian.
- Both apps support runtime toggling.
- `SharedGalleryLayout` adds/removes supplementary detail height in response.
- Ledger gallery items show/hide filename detail row based on the setting.
- Librarian toggles layout space only initially (no detail text required yet).

---

## Planned

### Tab pane focus-cycling
*(Sourced from: Librarian roadmap — keyboard parity; Ledger has this app-side in `MainContentView`)*

Reusable Tab key pane focus-cycling utility in `ThreePaneSplitViewController` (sidebar ↔ content). Currently implemented app-side in Ledger only; Librarian has not implemented it yet. Extracting to SharedUI would give Librarian the feature for free and remove the divergence risk.

Work needed:
- Add `installPaneFocusCyclingMonitor(sidebarView:contentView:)` to `ThreePaneSplitViewController`, following the same pattern as `installContentKeyboardMonitor`.
- Wire Ledger to use the shared implementation and remove the app-side Tab case from its keyboard monitor.
- Wire Librarian.

### Full native Quick Look integration in Ledger
*(Sourced from: Ledger roadmap — v1.3 and v1.5)*

Ledger's roadmap calls for a full native QuickLook rewrite in v1.3/v1.5. If that rewrite uses `QuickLookPanelCoordinator` as the foundation (currently Ledger uses a separate preview path), `QuickLookPanelCoordinator` may need extension to support Ledger's additional requirements (e.g., list-view navigation semantics, broader content type support). Track here if coordinator changes are needed.

### Ledger sidebar migration to AppKit
*(Sourced from: Ledger roadmap — v2.0)*

Ledger's v2.0 plans to rewrite its sidebar in AppKit. When that happens, `AppKitSidebarController` is the natural home. The controller may need extension for features Ledger requires that Librarian does not (drag to reorder, drag a folder onto the sidebar). Track those extensions here when they are specified.

### Gallery metadata subtitle customisation
*(Sourced from: Ledger roadmap — v1.3)*

Ledger plans per-item metadata subtitle customisation in the gallery. If the subtitle configuration is added to `GalleryMetrics` or `SharedGalleryLayout`, it belongs in SharedUI. If it stays as a cell-level concern inside Ledger's cell type, it stays app-side.

---

## Completed

- **[Done] Quick Look keyboard monitor** — `installContentKeyboardMonitor(contentView:onSpace:)` added to `ThreePaneSplitViewController` (v1.0.3). Spacebar handling extracted from Ledger; both apps now use the shared implementation.
- **[Done] Gallery context-menu selection infrastructure** — `ContextMenuSupport` extracted with `targetSelection` and `makeMenuItem` (v1.0.3). Both apps consume from SharedUI; app-specific menu item actions remain local.
- **[Done] QuickLookPanelCoordinator** — Generic coordinator with direct data source/delegate assignment, arrow key navigation, selection sync, and initial panel sizing (v1.0.1).
- **[Done] ThreePaneSplitViewController** — Three-pane shell base class with layout persistence, inspector toggle, and pane state sync (v1.0.1).
- **[Done] AppKitSidebarController** — Generic sidebar controller (v1.0.1).
- **[Done] SharedGalleryCollectionView / SharedGalleryLayout** — Gallery with adaptive layout and keyboard/mouse handling (v1.0.1).
- **[Done] Inspector SwiftUI building blocks** — Header, field rows, section containers, preview card, map view (v1.0.1).
- **[Done] Settings infrastructure** — SettingsWindowController, SettingsGridViewController, InspectorFieldSettingsViewController (v1.0.1).
- **[Done] Toolbar utilities** — WindowToolbarSetup, ToolbarItemFactory, ToolbarAppearanceAdapter (v1.0.1).
- **[Done] Menu builders and About panel** — makeStandardAppMenu, makeStandardWindowMenu, AboutPanel (v1.0.2).
