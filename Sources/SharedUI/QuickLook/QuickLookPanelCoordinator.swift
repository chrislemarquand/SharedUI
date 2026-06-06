#if os(macOS)
import AppKit
import Quartz

private final class TitledPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    init(url: URL, title: String?) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}

@MainActor
public final class QuickLookPanelCoordinator<SourceID: Hashable>: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    private var sourceItems: [SourceID] = []
    private var displayItems: [any QLPreviewItem] = []
    private var displayToSource: [URL: SourceID] = [:]
    private var panelItemTitle: String? = nil
    private var panelObservation: NSKeyValueObservation?
    private var lockedHeight: CGFloat?

    private var displayURLForSource: ((SourceID) -> URL?)?
    private var sourceFrameForSource: ((SourceID) -> NSRect?)?
    private var selectionDidChange: ((SourceID) -> Void)?
    private var moveSelection: ((MoveCommandDirection) -> SourceID?)?
    private var onWillClose: (() -> Void)?

    public override init() {
        super.init()
    }

    public func present(
        sourceItems: [SourceID],
        focusedItem: SourceID?,
        displayURLForSource: @escaping (SourceID) -> URL?,
        sourceFrameForSource: ((SourceID) -> NSRect?)? = nil,
        selectionDidChange: ((SourceID) -> Void)? = nil,
        moveSelection: ((MoveCommandDirection) -> SourceID?)? = nil,
        onWillClose: (() -> Void)? = nil,
        itemTitle: String? = nil
    ) {
        self.sourceItems = sourceItems
        self.panelItemTitle = itemTitle
        self.displayURLForSource = displayURLForSource
        self.sourceFrameForSource = sourceFrameForSource
        self.selectionDidChange = selectionDidChange
        self.moveSelection = moveSelection
        self.onWillClose = onWillClose

        guard !sourceItems.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        rebuildDisplayItems()
        guard !displayItems.isEmpty else { return }

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()

        if let focusedItem,
           let index = self.sourceItems.firstIndex(of: focusedItem) {
            panel.currentPreviewItemIndex = index
        } else {
            panel.currentPreviewItemIndex = 0
        }
        syncSelection(forIndex: panel.currentPreviewItemIndex)

        panelObservation = panel.observe(\.currentPreviewItemIndex, options: [.new]) { [weak self] _, change in
            guard let index = change.newValue else { return }
            DispatchQueue.main.async { [weak self] in
                self?.syncSelection(forIndex: index)
            }
        }

        lockedHeight = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidResize(_:)),
                                               name: NSWindow.didResizeNotification, object: panel)
        if !panel.isVisible {
            applyInitialPanelFrame(panel)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func refreshDisplayItems() {
        guard let panel = QLPreviewPanel.shared() else { return }
        let currentIndex = panel.currentPreviewItemIndex
        rebuildDisplayItems()
        panel.reloadData()
        if currentIndex >= 0, currentIndex < displayItems.count {
            panel.currentPreviewItemIndex = currentIndex
        }
        panel.refreshCurrentPreviewItem()
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        displayItems.count
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard displayItems.indices.contains(index) else { return nil }
        return displayItems[index]
    }

    public func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        guard let source = sourceItem(for: item),
              let sourceFrameForSource,
              let frame = sourceFrameForSource(source)
        else {
            return .zero
        }
        return frame
    }

    public func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        panelObservation = nil
        lockedHeight = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: panel)
        onWillClose?()
    }

    public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return false }

        switch event.keyCode {
        case KeyCode.leftArrow, KeyCode.upArrow:
            let direction: MoveCommandDirection = event.keyCode == KeyCode.leftArrow ? .left : .up
            return moveSelectionForQuickLook(panel: panel, direction: direction)
        case KeyCode.rightArrow, KeyCode.downArrow:
            let direction: MoveCommandDirection = event.keyCode == KeyCode.rightArrow ? .right : .down
            return moveSelectionForQuickLook(panel: panel, direction: direction)
        default:
            return false
        }
    }

    @objc private func panelDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let size = panel.frame.size
        guard size.width > 1, size.height > 1 else { return }

        if lockedHeight == nil {
            lockedHeight = size.height
        }
        let targetHeight = lockedHeight ?? size.height
        let aspectRatio = size.width / size.height
        let targetWidth = (targetHeight * aspectRatio).rounded()

        let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let finalWidth = min(targetWidth, screenFrame.width - 40)
        let finalHeight = finalWidth < targetWidth
            ? (finalWidth / aspectRatio).rounded()
            : targetHeight

        let origin = NSPoint(
            x: (screenFrame.minX + (screenFrame.width - finalWidth) / 2).rounded(),
            y: (screenFrame.minY + (screenFrame.height - finalHeight) / 2).rounded()
        )
        let targetFrame = NSRect(origin: origin, size: NSSize(width: finalWidth, height: finalHeight))
        guard panel.frame != targetFrame else { return }
        panel.setFrame(targetFrame, display: true)
    }

    private func moveSelectionForQuickLook(panel: QLPreviewPanel, direction: MoveCommandDirection) -> Bool {
        if let moveSelection,
           let selected = moveSelection(direction),
           let selectedIndex = sourceItems.firstIndex(of: selected) {
            panel.currentPreviewItemIndex = selectedIndex
            return true
        }
        return moveLinearly(panel: panel, delta: direction == .left || direction == .up ? -1 : 1)
    }

    private func moveLinearly(panel: QLPreviewPanel, delta: Int) -> Bool {
        guard !sourceItems.isEmpty else { return true }
        let current = panel.currentPreviewItemIndex
        let fallback = current >= 0 ? current : 0
        let proposed = fallback + delta
        let clamped = min(max(proposed, 0), sourceItems.count - 1)
        guard clamped != current else { return true }
        panel.currentPreviewItemIndex = clamped
        syncSelection(forIndex: clamped)
        return true
    }

    private func syncSelection(forIndex index: Int) {
        guard sourceItems.indices.contains(index) else { return }
        selectionDidChange?(sourceItems[index])
    }

    private func sourceItem(for item: (any QLPreviewItem)?) -> SourceID? {
        let url = (item as? TitledPreviewItem)?.previewItemURL
                ?? (item as? NSURL) as URL?
        guard let url else { return nil }
        return displayToSource[url.standardizedFileURL]
    }

    private func rebuildDisplayItems() {
        guard let displayURLForSource else { return }
        displayToSource.removeAll(keepingCapacity: true)
        var newSourceItems: [SourceID] = []
        var newDisplayItems: [any QLPreviewItem] = []
        for source in sourceItems {
            guard let displayURL = displayURLForSource(source)?.standardizedFileURL else { continue }
            guard displayURL.isFileURL else { continue }
            guard !displayURL.path.isEmpty else { continue }
            newSourceItems.append(source)
            if panelItemTitle != nil {
                newDisplayItems.append(TitledPreviewItem(url: displayURL, title: panelItemTitle))
            } else {
                newDisplayItems.append(displayURL as NSURL)
            }
            displayToSource[displayURL] = source
        }
        sourceItems = newSourceItems
        displayItems = newDisplayItems
    }

    private func applyInitialPanelFrame(_ panel: QLPreviewPanel) {
        let screenFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let targetWidth = min((screenFrame.width * 0.72).rounded(), 1400)
        let targetHeight = min((screenFrame.height * 0.78).rounded(), 980)
        let origin = NSPoint(
            x: (screenFrame.minX + (screenFrame.width - targetWidth) / 2).rounded(),
            y: (screenFrame.minY + (screenFrame.height - targetHeight) / 2).rounded()
        )
        let targetFrame = NSRect(origin: origin, size: NSSize(width: targetWidth, height: targetHeight))
        panel.setFrame(targetFrame, display: false)
        lockedHeight = targetHeight
    }
}
#endif
