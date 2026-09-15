#if os(macOS)
import AppKit

public struct SettingsTabDescriptor {
    public let symbolName: String
    public let label: String
    public let viewController: NSViewController
    /// Pass a fixed height for scrollable panes; nil uses fittingSize.
    public let preferredHeight: CGFloat?

    public init(
        symbolName: String,
        label: String,
        viewController: NSViewController,
        preferredHeight: CGFloat? = nil
    ) {
        self.symbolName = symbolName
        self.label = label
        self.viewController = viewController
        self.preferredHeight = preferredHeight
    }
}

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let tabsController: SettingsTabViewController
    public static let contentWidth: CGFloat = 620

    public init(tabs: [SettingsTabDescriptor]) {
        tabsController = SettingsTabViewController(tabs: tabs)
        let window = NSWindow(contentViewController: tabsController)
        window.title = tabs.first?.label ?? "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: Self.contentWidth, height: 100))
        window.minSize = NSSize(width: Self.contentWidth, height: 100)
        window.maxSize = NSSize(width: Self.contentWidth, height: 1200)
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SharedUI.SettingsWindow")
        super.init(window: window)
        tabsController.refreshWindowForSelectedTab(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func showWindowAndActivate() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class SettingsTabViewController: NSTabViewController {
    private let tabs: [SettingsTabDescriptor]

    init(tabs: [SettingsTabDescriptor]) {
        self.tabs = tabs
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        for tab in tabs {
            tab.viewController.title = tab.label
            let item = NSTabViewItem(viewController: tab.viewController)
            item.label = tab.label
            item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: tab.label)
            addTabViewItem(item)
        }
        selectedTabViewItemIndex = 0
        title = tabs.first?.label ?? "Settings"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshWindowForSelectedTab(animated: false)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        refreshWindowForSelectedTab(animated: true)
    }

    func refreshWindowForSelectedTab(animated: Bool) {
        guard let window = view.window else { return }
        let idx = selectedTabViewItemIndex
        guard tabs.indices.contains(idx) else { return }
        let tab = tabs[idx]
        title = tab.label
        window.title = tab.label

        let targetContentWidth = SettingsWindowController.contentWidth

        let targetContentHeight: CGFloat
        if let preferred = tab.preferredHeight {
            targetContentHeight = preferred
        } else if let vc = tabViewItems[idx].viewController {
            vc.view.layoutSubtreeIfNeeded()
            let h = vc.view.fittingSize.height
            guard h > 0 else { return }
            targetContentHeight = h
        } else {
            return
        }

        let frame = window.frame
        let currentContentRect = window.contentRect(forFrameRect: frame)
        let chromeHeight = frame.height - currentContentRect.height
        let maxContentHeight = (window.screen?.visibleFrame.height ?? 800) - chromeHeight
        let clampedContentHeight = min(targetContentHeight, maxContentHeight)
        let heightDelta = clampedContentHeight - currentContentRect.height
        let widthDelta = targetContentWidth - currentContentRect.width
        guard abs(heightDelta) > 0.5 || abs(widthDelta) > 0.5 else { return }

        window.minSize = NSSize(width: targetContentWidth, height: 100)
        window.maxSize = NSSize(width: targetContentWidth, height: 1200)

        var targetFrame = frame
        targetFrame.size.width += widthDelta
        targetFrame.size.height += heightDelta
        targetFrame.origin.y -= heightDelta
        // Growing downward from wherever the window already happens to be sitting can push
        // its bottom edge below the visible screen — `constrainFrameRect` below only
        // guarantees the title bar stays reachable, not that the whole window fits. The
        // height clamp above already ensures the (possibly-clamped) content height fits the
        // screen; reposition vertically here so the grown window is actually fully visible,
        // not just draggable.
        if let visibleFrame = window.screen?.visibleFrame {
            if targetFrame.minY < visibleFrame.minY {
                targetFrame.origin.y = visibleFrame.minY
            }
            let maxY = visibleFrame.maxY - targetFrame.height
            if targetFrame.origin.y > maxY {
                targetFrame.origin.y = maxY
            }
        }
        let constrainedFrame = window.constrainFrameRect(targetFrame, to: window.screen)
        window.setFrame(constrainedFrame, display: true, animate: animated)
    }
}
#endif
