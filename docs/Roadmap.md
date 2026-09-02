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

### macOS 26 chrome-workaround audit on Golden Gate (macOS 27)
*(Sourced from: Ledger v1.2.3 Golden Gate work, 2026-08-15; benefits Ledger and Librarian)*

Every custom chrome hack from the macOS 26 Liquid Glass cycle was an attempt to get system behaviour without good APIs. Golden Gate's AppKit surface is nearly unchanged (SDK is versioned 26.5; the only post-26.0 addition is `NSScrollEdgeEffectStyle` `.soft`/`.hard` via `preferredScrollEdgeEffectStyle` on titlebar/split-view accessory controllers, macOS 26.1), so the expected wins are **behavioural** fixes in the OS, not adoption work. Method: disable each workaround on macOS 27, observe, then delete / replace with `NSScrollEdgeEffectStyle` / keep with a note naming the beta it was last verified against.

Inventory (audited 2026-08-15):
1. **[Done, v1.4 Phase 4.3, 2026-09-02]** `AppKitSidebarController.ScrollContentInsetMode.manual(top:)` + `reapplyScrollContentInsetMode()` — confirmed zero callers anywhere. Deleted the enum, the public mode property, and the method entirely (a single-case mode enum is pointless once the other case is gone).
2. **[Root cause fixed, v1.4 Phase 4.3, 2026-09-02]** `AppKitSidebarController.applyInitialScrollPositionIfNeeded()` scroll-origin repair — initially just re-confirmed live as still needed (disabling it reproduced the visible snap on real macOS 27, screen-recorded). The user then pushed for the actual root cause rather than accepting the symptom-level patch permanently: both apps' `MainWindowController.init` attached the toolbar to the window in `viewWillAppear`, well after `NSWindow(contentViewController:)` had already forced the content view controller through a real layout pass with `window.toolbar` still nil — so `automaticallyAdjustsContentInsets` computed a zero top inset for the sidebar, then applied a fresh nonzero one once the toolbar appeared, without correcting the already-settled scroll origin. Fixed by reordering window construction in both apps: create the window without a content view controller, install the toolbar on it, only then assign `contentViewController`. This repair function is now a redundant no-op safety net in the fixed path, left in place rather than deleted (harmless, costs nothing, and the sidebar's own initial-fit logic still needs the `didApplyInitialScrollPosition` bookkeeping for other cases).
3. **[Done, v1.4 Phase 4.3, 2026-09-02]** Ledger `MainContentView.viewWillAppear` window-config timing — moved the config call to `viewDidAppear` on real macOS 27, had the user watch several fresh launches for the original sharp-cornered shadow flash. Confirmed moot ("macOS27's design is so different it's all moot now"). Kept the call in `viewWillAppear` (the conventional placement) and removed the now-stale workaround comment — no reason left to deviate from it.
4. **[Done, v1.4 Phase 4.3, 2026-09-02]** Librarian `MainSplitViewController.viewWillAppear` — same test and outcome as 3, comment removed. Superseded by item 2's window-construction-order fix, which also touched this file's toolbar installation (moved to `MainWindowController.init`) and fixed a real latent bug it exposed: `ContentController.selectedAssetIdentifiers()` force-unwrapped `collectionView`, which crashed once toolbar item state could be evaluated before that controller's view had loaded. Now guarded on `isViewLoaded`.
5. **[Done, v1.4 Phase 4.3, 2026-09-02]** "Defer pane state sync past collapse animation" (`61c888a`) — fired the sync immediately (no 0.35s defer) on real macOS 27, had the user repeatedly toggle sidebar/inspector in both Ledger and Librarian. Confirmed moot: animation is smooth, no snap. Deferral removed.
6. **[Done, v1.4 Phase 4.3, 2026-09-02]** `ToolbarAppearanceAdapter` — macOS 26 dark-mode workaround, dormant since the `ToolbarShellController` refactor (zero callers). Deleted the class outright (dead code, nothing to re-verify). Smoke-tested light↔dark toggling on real macOS 27 with Ledger running afterward, as confirmation rather than a gate: toolbar buttons render correctly with no stale-appearance artifacts, confirming the OS behaviour genuinely improved and this workaround is no longer needed.

7. **[Done, v1.4 Phase 4.3, 2026-09-02]** `AppKitSidebarController` sidebar-cell rebuild — replaced the mutually-exclusive `titleTrailingToCount`/`titleTrailingToCell` constraint pair with a plain horizontal `NSStackView` (icon/title/count), relying on its standard hidden-arranged-subview behaviour (collapses its own space and surrounding spacing) instead of manually toggling constraints on every reuse. Kept scrollable-only-during-rename unchanged. Verified live in both apps: badge and no-badge rows both lay out correctly (Librarian's badge-heavy sidebar, Ledger's plain one). `SidebarCellView.backgroundStyle`'s emphasized-colour override was left untouched — that's the separate "Sidebar inactive-window label colour" investigation below, not resolved by this layout change.

Not workarounds (checked, keep): `SharedGalleryLayout` section insets; Librarian notice-bar safe-area constraint; Ledger's `#available(macOS 26.0)` toolbar `.prominent` style (deliberate API adoption).

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
