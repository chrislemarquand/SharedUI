import AppKit

/// Base class for the standard three-pane (sidebar | content | inspector) window layout.
///
/// Handles all structural setup and the six behavioural improvements over a naive
/// NSSplitViewController subclass:
///   1. Initial content split applied in viewDidLayout (layout settled), not viewDidAppear
///   2. Both "Subview Frames" and "Divider Positions" keys checked for persisted layout
///   3. Initial inspector visibility ensured in viewDidAppear with a guard flag
///   4. Deferred pane state sync with coalescing to avoid redundant updates
///   5. Both sidebar and inspector collapse state reported via onPaneStateChanged
///   6. Resize observation on the outer split, not the inner
///
/// App subclasses supply the three pane view controllers and autosave names, wire
/// onPaneStateChanged to update their model, and add all app-specific logic on top.
open class ThreePaneSplitViewController: NSSplitViewController {

    // MARK: - Public interface

    /// Fired on each coalesced pane sync. Update model collapsed state and refresh toolbar here.
    public var onPaneStateChanged: (() -> Void)?

    /// Read/write sidebar collapsed state.
    public var isSidebarCollapsed: Bool {
        get { sidebarItem.isCollapsed }
        set { sidebarItem.isCollapsed = newValue }
    }

    /// Read/write inspector collapsed state.
    public var isInspectorCollapsed: Bool {
        get { inspectorItem.isCollapsed }
        set { inspectorItem.isCollapsed = newValue }
    }

    /// The inner split view — bind toolbar inspector tracking separator to dividerIndex 0.
    public var innerSplitView: NSSplitView { contentSplitController.splitView }

    /// Coalesced pane state sync — safe to call multiple times in the same run loop pass.
    public func schedulePaneStateSync() {
        guard !isPaneStateSyncScheduled else { return }
        isPaneStateSyncScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isPaneStateSyncScheduled = false
            self.onPaneStateChanged?()
        }
    }

    // MARK: - Standardised pane metrics (identical for all apps using SharedUI)

    private enum Metrics {
        static let sidebarMin:          CGFloat = 220
        static let contentMin:          CGFloat = 300
        static let inspectorMin:        CGFloat = 260
        static let inspectorMax:        CGFloat = 600
        static let initialContentRatio: CGFloat = 0.7
        static let stableWidthBuffer:   CGFloat = 240
    }

    // MARK: - Private split layout

    private let contentSplitController = NSSplitViewController()
    private let sidebarItem:       NSSplitViewItem
    private let contentItem:       NSSplitViewItem
    private let contentBrowserItem: NSSplitViewItem
    private let inspectorItem:     NSSplitViewItem

    private let inspectorStartsVisible: Bool
    private var splitResizeObservers: [NSObjectProtocol] = []
    private var isPaneStateSyncScheduled = false
    private var didApplyInitialContentSplit = false
    private var didApplyInitialInspectorVisibility = false

    private let mainAutosaveName: String
    private let contentAutosaveName: String

    // MARK: - Init

    public init(
        sidebar: NSViewController,
        content: NSViewController,
        inspector: NSViewController,
        mainSplitAutosaveName: String,
        contentSplitAutosaveName: String,
        inspectorStartsVisible: Bool = true
    ) {
        mainAutosaveName          = mainSplitAutosaveName
        contentAutosaveName       = contentSplitAutosaveName
        self.inspectorStartsVisible = inspectorStartsVisible

        // Split items must be created before super.init.
        sidebarItem       = NSSplitViewItem(sidebarWithViewController: sidebar)
        contentItem       = NSSplitViewItem(viewController: contentSplitController)
        contentBrowserItem = NSSplitViewItem(viewController: content)
        inspectorItem     = NSSplitViewItem(inspectorWithViewController: inspector)

        super.init(nibName: nil, bundle: nil)

        // Sidebar — no holdingPriority override so the user can freely drag the
        // sidebar divider in both directions. Window resizes are absorbed by the
        // content pane (slightly lower priority below).
        sidebarItem.minimumThickness    = Metrics.sidebarMin
        sidebarItem.canCollapse         = true
        sidebarItem.allowsFullHeightLayout = true

        // Content pane — just below .defaultLow so it absorbs window resizes
        // before the sidebar does.
        contentBrowserItem.minimumThickness = Metrics.contentMin
        contentBrowserItem.holdingPriority  = NSLayoutConstraint.Priority(
            rawValue: NSLayoutConstraint.Priority.defaultLow.rawValue - 1)

        // Inspector pane
        inspectorItem.minimumThickness = Metrics.inspectorMin
        inspectorItem.maximumThickness = Metrics.inspectorMax
        inspectorItem.canCollapse      = true
        inspectorItem.holdingPriority  = .defaultLow

        // Keep the inner split from resisting outer resize.
        contentItem.holdingPriority = .defaultLow

        // Prevent sidebar and inspector content from forcing pane expansion.
        sidebar.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sidebar.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inspector.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inspector.view.setContentHuggingPriority(.defaultLow, for: .horizontal)

        contentSplitController.addSplitViewItem(contentBrowserItem)
        contentSplitController.addSplitViewItem(inspectorItem)
        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    open override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autosaveName = NSSplitView.AutosaveName(mainAutosaveName)
        contentSplitController.splitView.isVertical = true
        contentSplitController.splitView.dividerStyle = .thin
        contentSplitController.splitView.autosaveName = NSSplitView.AutosaveName(contentAutosaveName)
        schedulePaneStateSync()
        installSplitResizeObserver()
    }

    open override func viewDidAppear() {
        super.viewDidAppear()
        ensureInitialInspectorVisibility()
    }

    open override func viewDidLayout() {
        super.viewDidLayout()
        applyInitialContentSplitIfNeeded()
    }

    open override func viewWillDisappear() {
        super.viewWillDisappear()
        splitResizeObservers.forEach { NotificationCenter.default.removeObserver($0) }
        splitResizeObservers = []
    }

    // MARK: - Inspector toggle

    /// Toggles the inspector with animation, preserving first-responder focus.
    @objc override public func toggleInspector(_ sender: Any?) {
        let previousResponder = view.window?.firstResponder
        inspectorItem.animator().isCollapsed.toggle()
        schedulePaneStateSync()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.view.window else { return }
            if let previousResponder {
                _ = window.makeFirstResponder(previousResponder)
            }
        }
    }

    // MARK: - Private

    private func installSplitResizeObserver() {
        guard splitResizeObservers.isEmpty else { return }
        // Observe both the outer split (sidebar drag, window resize) and the inner
        // split (inspector divider drag) so pane state stays in sync regardless of
        // how the user changes pane sizes.
        for sv in [splitView, contentSplitController.splitView] {
            let obs = NotificationCenter.default.addObserver(
                forName: NSSplitView.didResizeSubviewsNotification,
                object: sv,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.schedulePaneStateSync()
                }
            }
            splitResizeObservers.append(obs)
        }
    }

    private func ensureInitialInspectorVisibility() {
        guard !didApplyInitialInspectorVisibility else { return }
        didApplyInitialInspectorVisibility = true
        inspectorItem.isCollapsed = !inspectorStartsVisible
        schedulePaneStateSync()
    }

    private func applyInitialContentSplitIfNeeded() {
        guard !didApplyInitialContentSplit else { return }
        if hasPersistedContentSplitLayout() {
            didApplyInitialContentSplit = true
            return
        }
        let split = contentSplitController.splitView
        guard split.arrangedSubviews.count == 2 else { return }

        let totalWidth = split.bounds.width
        guard totalWidth > 0 else { return }

        // Wait until the outer split has settled to a stable width.
        let threshold = max(Metrics.contentMin + Metrics.inspectorMin + Metrics.stableWidthBuffer, 860)
        guard totalWidth >= threshold else { return }

        let target = min(
            max(totalWidth * Metrics.initialContentRatio, Metrics.contentMin),
            totalWidth - Metrics.inspectorMin)
        guard target.isFinite, target > 0 else { return }
        split.setPosition(target, ofDividerAt: 0)
        didApplyInitialContentSplit = true
    }

    private func hasPersistedContentSplitLayout() -> Bool {
        let d = UserDefaults.standard
        return d.object(forKey: "NSSplitView Subview Frames \(contentAutosaveName)") != nil
            || d.object(forKey: "NSSplitView Divider Positions \(contentAutosaveName)") != nil
    }
}
