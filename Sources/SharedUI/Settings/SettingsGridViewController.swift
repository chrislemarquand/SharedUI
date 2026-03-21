import AppKit

/// Base view controller for settings panes that use the standard label | control(s) grid layout.
/// Subclasses override `makeRows()` to return their grid rows; the base class handles all
/// NSGridView construction, constraints, and column alignment.
/// Call `rebuildGrid()` to rebuild the grid in-place (e.g. after dynamic content changes).
open class SettingsGridViewController: NSViewController {
    private var currentGrid: NSGridView?

    override open func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        rebuildGrid()
    }

    /// Override to return the rows for the grid. Each inner array is one row;
    /// the outer array is all rows top-to-bottom. All rows must have the same column count.
    open func makeRows() -> [[NSView]] { [] }

    /// Rebuilds the grid by calling `makeRows()`. Safe to call at any time after `viewDidLoad`.
    public func rebuildGrid() {
        currentGrid?.removeFromSuperview()
        currentGrid = nil

        let rows = makeRows()
        guard !rows.isEmpty else { return }

        let grid = NSGridView(views: rows)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 14
        grid.yPlacement = .center

        // Column 0 is always the right-aligned label column.
        // Remaining columns default to leading via NSGridView's default xPlacement.
        let columnCount = rows.map(\.count).max() ?? 0
        if columnCount > 0 {
            grid.column(at: 0).xPlacement = .trailing
            for i in 1..<columnCount {
                grid.column(at: i).xPlacement = .leading
            }
        }

        view.addSubview(grid)
        currentGrid = grid

        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            grid.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Factory methods

    public func makeCategoryLabel(title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .right
        return label
    }

    public func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    public func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        return button
    }

    public func makeCheckbox(title: String, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        return button
    }

    public func makeRadioButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(radioButtonWithTitle: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        return button
    }

    /// Creates a read-only breadcrumb path control. Pass nil to start empty; call
    /// `updatePathControl(_:url:)` later to populate it once the URL is known.
    /// When a URL is supplied the control shows at most three path components
    /// (home dir → parent → item), matching the Photos.app style.
    public func makePathControl(url: URL?) -> NSPathControl {
        let control = NSPathControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.pathStyle = .standard
        control.isEditable = false
        control.focusRingType = .none
        control.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        if let url {
            control.url = url
            let all = control.pathItems
            if all.count > 3 { control.pathItems = Array(all.suffix(3)) }
        }
        return control
    }
}
