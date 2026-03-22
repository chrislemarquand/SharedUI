import AppKit

@MainActor
public final class WindowFramePersistenceController: NSObject {
    private weak var window: NSWindow?
    private let autosaveName: String

    public init(
        window: NSWindow,
        autosaveName: String,
        minSize: NSSize? = nil,
        defaultContentSize: NSSize? = nil,
        centerWhenUnrestored: Bool = true
    ) {
        self.autosaveName = autosaveName
        super.init()
        self.window = window

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

        window.setFrameAutosaveName(autosaveName)
        registerObservers(for: window)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func registerObservers(for window: NSWindow) {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleWindowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
        center.addObserver(
            self,
            selector: #selector(handleWindowDidEndLiveResize),
            name: NSWindow.didEndLiveResizeNotification,
            object: window
        )
    }

    @objc
    private func handleWindowDidMove() {
        persistFrame()
    }

    @objc
    private func handleWindowDidEndLiveResize() {
        persistFrame()
    }

    private func persistFrame() {
        window?.saveFrame(usingName: autosaveName)
    }
}
