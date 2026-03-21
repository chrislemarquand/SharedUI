# SharedUI Architecture

Design rules, boundary decisions, and the reasoning behind non-obvious implementation choices.

---

## What belongs in SharedUI

A component belongs in SharedUI when it meets all three of these:

1. **Two or more apps need it** — either currently or demonstrably soon. One app is not enough; the boundary gets blurry and the abstraction is harder to validate.
2. **The correct implementation is non-trivial to discover independently** — if two apps would each write something subtly different and the difference would cause a bug in one of them, it belongs here. The Quick Look keyboard monitor is the canonical example: two apps wrote it differently, one broke, and the fix was to consolidate.
3. **The interface is stable enough to commit to** — SharedUI imposes a cost on every consumer when it changes. Don't extract something that's still finding its shape.

Components that do **not** belong in SharedUI:
- App-specific data models, actions, or navigation logic
- Any closure callback implementation (the closure itself, not the hook)
- App-specific guard conditions (e.g., "only fire when the gallery is active") — these belong in the app's closure, not in SharedUI's event monitor
- One-off UI that hasn't proven itself reusable across at least two apps

---

## Design patterns

### Closure callbacks over delegation

All major components use closure-based callbacks rather than delegate protocols. This avoids the `@objc` delegation overhead in generic code and makes the call sites self-documenting. The tradeoff is that closures capture weakly and the call site must manage retention — this is intentional; it keeps SharedUI components ignorant of app models.

Where a delegate protocol is required by the system (e.g., `QLPreviewPanelDataSource`, `NSCollectionViewDelegate`), SharedUI implements the protocol internally and translates events to closures before surfacing them to the app.

### Generics for type-safe composition

`AppKitSidebarController` and `QuickLookPanelCoordinator` are generic over their item type. This avoids stringly-typed identifiers while keeping SharedUI decoupled from any specific app model. The constraint is `Hashable` rather than a richer protocol — just enough for identity, nothing more.

The `@objc` limitation on generic Swift classes means some internal delegation uses a proxy object pattern (see `AppKitSidebarController`'s outline view delegate); this is an implementation detail and not visible to callers.

### Metrics as configurable structs

`GalleryMetrics` and `InspectorMetrics` centralise all sizing, spacing, and appearance constants. `GalleryMetrics` is a configurable struct with a `.default` preset; apps mutate only the values they need to differ. `InspectorMetrics` is a fixed enum because inspector sizing has not yet diverged between apps — if it does, it should become configurable in the same way.

This prevents magic numbers spreading across both codebases and ensures that layout changes can be made in one place.

### Deferred layout in ThreePaneSplitViewController

The initial content pane split is applied in `viewDidLayout()`, not `viewDidAppear()`. The reason: `viewDidAppear` fires before the outer split has settled to a stable width after the window is resized or restored from UserDefaults. Applying the split too early produces an incorrect ratio. `viewDidLayout` may fire multiple times; the implementation guards with `didApplyInitialContentSplit` and a minimum stable-width threshold before committing.

Similarly, initial inspector visibility is applied in `viewDidAppear` with a guard flag, not in `viewDidLoad`, because the split item's `isCollapsed` property has no effect until the split view is in the window hierarchy.

### Direct data source assignment for QuickLookPanelCoordinator

`QuickLookPanelCoordinator` sets `QLPreviewPanel.shared().dataSource = self` and `.delegate = self` directly, bypassing the responder chain protocol (`acceptsPreviewPanelControl`, `beginPreviewPanelControl`, `endPreviewPanelControl`).

The responder chain protocol is the standard macOS pattern for QL integration but has a significant downside: when the panel is opened by user gesture (space, ⌘Y), macOS walks the responder chain to find a controller, which means the panel's data source depends on the current first responder at the moment of opening. For programmatic control (our use case), direct assignment is simpler and more predictable. The tradeoff is that apps must not also implement the responder chain protocol, as it will conflict.

### Coalesced pane state sync

`schedulePaneStateSync()` posts a single deferred `onPaneStateChanged` call via `DispatchQueue.main.async` with a boolean guard to prevent multiple firings in the same run loop pass. This is important because split resize notifications fire rapidly during drag and because multiple operations (collapse sidebar, resize window) can happen in the same pass. Apps should call `schedulePaneStateSync()` anywhere they change pane state; the coalescing is automatic.

---

## Module boundaries

### ThreePaneSplitViewController and keyboard handling

The shell owns keyboard monitors that are structural to the three-pane layout — specifically, shortcuts that depend on pane focus and must gate on whether the key window is this app's window (not a panel). The spacebar → Quick Look monitor (`installContentKeyboardMonitor`) belongs here because:

- Its correctness depends on strict first-responder gating relative to the content pane
- Both apps need it and had independently introduced bugs by implementing it differently
- The fix (synchronous call, strict content-view focus guard) is a single implementation that both apps consume

App-specific keyboard shortcuts (shortcuts whose action is defined entirely in the app, with no structural dependency on the shell's pane layout) belong in the app, not in SharedUI. A per-app monitor installed in the app subclass's `viewDidLoad` is the correct home for those.

### Inspector

The inspector SwiftUI components are intentionally read-only building blocks. Write actions (field editing, apply buttons) are app-specific and should be composed on top of these primitives in each app's inspector implementation. Adding write affordances to SharedUI inspector components requires explicit discussion — it would couple SharedUI to edit-session semantics that differ between apps.

### Gallery and keyboard

`SharedGalleryCollectionView` handles keyboard navigation (arrows, Escape, Return) via closure callbacks. It does not handle the spacebar — that's intentional. Space triggers Quick Look, which is a shell-level concern (see above). If the gallery received and consumed space, it would conflict with the shell monitor. Do not add space handling to `SharedGalleryCollectionView`.

---

## Version discipline

SharedUI follows the local-path package workflow: both consuming apps pin to the same local path and changes are applied synchronously across the suite. There is no independent versioning between consuming apps.

Changes to SharedUI public API must be accompanied by updates to all consumers in the same working session. Silent breakage (e.g., adding a required parameter to an existing method) is acceptable only if all call sites are updated immediately. Do not leave a consuming app in a broken state.

Breaking changes that cannot be updated atomically should be additive first (new method alongside old) and the old form removed only after all callers are migrated.
