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

### Sidebar inactive-window label colour
*(Sourced from: observed in both Ledger and Librarian)*

When a window loses focus, sidebar SF Symbol icons correctly grey out but item label text stays black instead of dimming to match. Native macOS sidebars dim both. Investigation suggests `SidebarCellView.backgroundStyle` correctly calls `super` and does not manually set `textField.textColor`, so the root cause is not obvious from the code — it may be that AppKit's automatic propagation of `backgroundStyle` to the text field is not firing for unselected rows on key-window transitions in the current macOS version. Needs further investigation and testing.

### Gallery metadata subtitle customisation
*(Sourced from: Ledger roadmap — v1.3)*

Ledger plans per-item metadata subtitle customisation in the gallery. If the subtitle configuration is added to `GalleryMetrics` or `SharedGalleryLayout`, it belongs in SharedUI. If it stays as a cell-level concern inside Ledger's cell type, it stays app-side.

---

## Completed

- **[Done] InspectorRatingFlagView** — Star rating (0–5), three-way pick/flag cycle (unflagged/picked/rejected), and colour label menu. Generic widget taking values and callbacks; wired to Ledger's pending-edits model. NSColor.system* colours, NSImage drawn circles to avoid macOS template rendering in menu items.
- **[Done] InspectorHeaderView pending change indicator** — `pendingChange: Bool` parameter added; shows orange dot before title when a staged rename is pending. Used by Ledger v1.2 to indicate batch rename state.
- **[Done] Ledger sidebar migration to AppKit** — Ledger now uses `AppKitSidebarController` (`LedgerSidebarTypes.swift`). The planned extensions (drag to reorder) were not needed at migration time.
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
