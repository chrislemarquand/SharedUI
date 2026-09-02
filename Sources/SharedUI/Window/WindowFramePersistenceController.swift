#if os(macOS)
import AppKit

@MainActor
public final class WindowFramePersistenceController: NSObject {
    public init(
        window: NSWindow,
        autosaveName: String,
        minSize: NSSize? = nil,
        defaultContentSize: NSSize? = nil,
        centerWhenUnrestored: Bool = true
    ) {
        super.init()

        if let minSize {
            window.minSize = minSize
        }

        let restored = window.setFrameUsingName(autosaveName)
        if !restored, let defaultContentSize {
            window.setContentSize(defaultContentSize)
            if centerWhenUnrestored {
                window.center()
            }
        }

        // v1.4 Phase 4.2: setFrameAutosaveName already makes AppKit observe move/live-resize-end
        // and persist the frame itself — this used to also register its own didMove/
        // didEndLiveResize observers that wrote the identical value to the identical key, which
        // was harmless but pure duplication (docs/window-list-resize-diagnosis-2026-07.md #4).
        window.setFrameAutosaveName(autosaveName)
    }
}
#endif
