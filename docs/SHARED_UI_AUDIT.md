# SharedUI Audit — Librarian & Ledger

_Generated 2026-03-23_

Analysis of duplicate UI implementations across Librarian and Ledger, opportunities to consolidate into SharedUI, and places where native APIs could replace custom implementations.

---

## 1. Duplicate implementations that should move to SharedUI

### Notice bar / info banner
**Librarian** hand-rolls `archivedNoticeBar` in `ContentController.swift` — an `NSView` with label, action button, dismiss button, divider, and height-constraint toggling. **Ledger** doesn't have this yet but would benefit (e.g. "unsaved edits" warnings). A shared `NoticeBar` component in SharedUI would serve both apps.

### Closure-based NSMenuItem
**Ledger** has `ClosureMenuItem` (NSMenuItem subclass storing a closure to avoid `@objc` selector proliferation) in `MainContentView.swift`. **Librarian** doesn't have this but uses the same pattern manually in context menus. This should be a SharedUI utility — small, universally useful.

### Zoom transition anchor
Both apps implement an identical pattern: capture the visible item's index before a grid column-count change, then scroll back to it after layout completes, guarded by a generation token. **Librarian** has this in `ContentController.swift`, **Ledger** in `BrowserGalleryView.swift`. This is tightly coupled to `SharedGalleryCollectionView` and `SharedGalleryLayout` — it should live alongside them in SharedUI.

### Thumbnail cell with pending-state overlay
**Ledger**'s `AppKitGalleryItem` builds a custom `NSCollectionViewItem` with thumbnail, selection highlight, pending dot, and title label. **Librarian**'s `AssetGridItem` does the same (thumbnail, selection highlight, no pending dot but similar structure). The core cell layout — square thumbnail with optional corner overlays and selection background — could be a shared base class or configurable item, with apps adding their specific overlays.

### Inspector field settings (hierarchical checkbox toggle)
**Ledger** has its own `InspectorSettingsViewController` in `SettingsWindowController.swift` with section-level mixed-state toggles and field-level checkboxes. SharedUI already has `InspectorFieldSettingsViewController` which does the same thing. **Ledger appears to be duplicating this** rather than using the SharedUI version. The SharedUI version should be adopted.

### Selection feedback-loop guards
Both apps use `isApplyingProgrammaticSelection` / `isApplyingProgrammaticSort` boolean flags to prevent NSCollectionView/NSTableView delegate callbacks from triggering model updates during programmatic selection changes. This pattern could be a small protocol or wrapper in SharedUI (e.g. a `ProgrammaticSelectionGuard` that wraps the block and suppresses delegate callbacks).

---

## 2. Custom implementations where native APIs exist

### NSAlert for confirmations — could use `.confirmationDialog` in SwiftUI sheets
**Librarian**'s `ArchiveRootPrompts.swift` and **Ledger**'s backup-clearing confirmation both build `NSAlert` instances programmatically. Where these are triggered from SwiftUI sheet contexts (archive export/import), SwiftUI's `.confirmationDialog` modifier would be more natural. For AppKit-only contexts, the existing `NSAlert+SheetOrModal` extension in SharedUI is fine.

### `NSHostingController` wrapping where `NSHostingView` suffices
Both apps frequently create an `NSHostingController`, call `addChild()`, extract `.view`, and constrain it. When no view controller lifecycle is needed (the SwiftUI view is purely presentational), `NSHostingView` is simpler — no child controller management, no `sizingOptions` workaround. Candidates:
- **Librarian**: `GalleryPlaceholderView` hosting in `ContentController`
- **Ledger**: `BrowserPlaceholderView` hosting in `BrowserContainerViewController`

### Manual keyboard event monitors
Both apps add `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` in their split view controllers for Tab/Shift-Tab pane switching, ⌘⌥I inspector toggle, and zoom shortcuts. SharedUI's `KeyboardShortcutSupport` already provides the detection helpers, but the actual event monitor installation is duplicated. A shared `installStandardKeyboardMonitor(sidebar:content:inspector:)` on `ThreePaneSplitViewController` could eliminate this.

### Manual `CATransition` for thumbnail crossfade
**Ledger**'s `BrowserListIconView` applies a `CATransition` fade when swapping thumbnails. On macOS 14+, `NSView.transition(with:options:)` or SwiftUI's `.contentTransition(.opacity)` handle this natively. For AppKit image views, `NSImageView` with `animates = true` combined with layer-backed views can achieve the same without manual `CATransition` setup.

### Manual DMS coordinate parsing
**Ledger**'s `InspectorView.swift` has a hand-rolled `parseCoordinate()` function using `NSRegularExpression` to parse GPS coordinates in degrees/minutes/seconds format. `CLLocationCoordinate2D` doesn't parse strings natively, but `MKCoordinateFormatter` (macOS 26) or a small shared parser in SharedUI would prevent this from being duplicated if Librarian ever needs location editing.

### Window subtitle priority system
**Librarian**'s `MainSplitViewController` has `LibrarianWindowSubtitlePriority` — an enum that computes which status message takes precedence (import > indexing > analysis > pending > archive issues > status message). **Ledger** has simpler subtitle logic but the same concept. A shared `WindowSubtitleProvider` protocol with a priority-based resolution method would be cleaner than each app reimplementing priority logic.

---

## 3. Code that's fine as-is

These are app-specific and don't warrant sharing:
- **Librarian**'s archive pipeline UI (import/export sheets, relink flow, binding evaluator) — entirely Librarian-specific
- **Ledger**'s preset editor and import sheets — Ledger-specific workflow
- Both apps' `AppDelegate` implementations — different enough to not share
- Sidebar item definitions (`SidebarItem` / `LedgerSidebarItem`) — the protocol is shared, the data is correctly app-specific

---

## Summary — priority order

| Priority | What | Effort |
|---|---|---|
| **Now** | NoticeBar → SharedUI | Small |
| **Quick wins** | `ClosureMenuItem` → SharedUI/Utilities | Tiny |
| | Zoom transition anchor → SharedUI/Gallery | Small |
| | Ledger: adopt `InspectorFieldSettingsViewController` from SharedUI | Small |
| **Medium** | Shared gallery item base class (thumbnail + selection + overlays) | Medium |
| | Keyboard monitor installation on `ThreePaneSplitViewController` | Small |
| | `NSHostingController` → `NSHostingView` where no lifecycle needed | Small |
| **Lower** | Window subtitle priority protocol | Small |
| | Selection feedback-loop guard utility | Tiny |
| | Coordinate parser in SharedUI (only if Librarian needs it) | Tiny |
