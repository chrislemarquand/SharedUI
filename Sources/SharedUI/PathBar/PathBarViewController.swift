#if os(macOS)
import AppKit

/// A path bar that displays a file-system URL as clickable breadcrumb cells.
///
/// Designed to be placed at the bottom of a browser pane. Set `url` to drive the
/// display, and handle `onItemClicked` to respond to user navigation. Show/hide
/// logic and UserDefaults persistence are the caller's responsibility.
///
/// Use `preferredHeight` as the height constraint when adding this controller's
/// view to a parent layout.
@MainActor
public final class PathBarViewController: NSViewController {

    // MARK: - Public interface

    /// The height to use when adding this view to a parent layout.
    public static let preferredHeight: CGFloat = 32

    /// The path to display. Set to `nil` to show `placeholderString`.
    public var url: URL? {
        didSet { applyURL() }
    }

    /// Displayed when `url` is `nil`.
    public var placeholderString: String = "" {
        didSet { pathControl.placeholderString = placeholderString }
    }

    /// Called with the URL of whichever breadcrumb component the user clicked.
    public var onItemClicked: ((URL) -> Void)?

    /// When set, and `url` is at or under `root`, the breadcrumb starts at `root` labeled
    /// `title` instead of walking the real filesystem ancestors above it — needed for a
    /// location whose on-disk path doesn't match its user-facing name (e.g. iCloud Drive, whose
    /// real path is a nested, Apple-internal folder name that some macOS versions render as two
    /// confusingly-duplicated "iCloud Drive" breadcrumb segments if handed to `NSPathControl`
    /// directly). `nil` (the default) preserves plain automatic behavior for every other path.
    public var rootOverride: (title: String, root: URL)? {
        didSet { applyURL() }
    }


    // MARK: - Private

    private let pathControl = NSPathControl()
    private let separator = NSBox()

    // MARK: - View lifecycle

    public override func loadView() {
        view = NSView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

        pathControl.pathStyle = .standard
        pathControl.isEditable = false
        pathControl.focusRingType = .none
        pathControl.controlSize = .small
        pathControl.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        pathControl.translatesAutoresizingMaskIntoConstraints = false
        // NSPathControl's default (.required) horizontal compression resistance means
        // an unusually long path (many nested components) fights the width constraint
        // below instead of truncating, which can inflate the window's effective width.
        // Let it compress freely — NSPathControl truncates/overflows into a popup
        // button on its own once it's allowed to shrink.
        pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathControl.target = self
        pathControl.action = #selector(handlePathControlClick(_:))
        view.addSubview(pathControl)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: view.topAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Centre the small control in the available space below the separator.
            pathControl.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0.5),
            pathControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            pathControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])
    }

    @objc private func handlePathControlClick(_ sender: NSPathControl) {
        guard let url = sender.clickedPathItem?.url else { return }
        onItemClicked?(url)
    }

    private func applyURL() {
        guard let url else {
            pathControl.url = nil
            return
        }
        pathControl.url = url
        guard let rootOverride, isURL(url, atOrUnder: rootOverride.root) else { return }
        collapseAncestors(above: rootOverride)
    }

    private func isURL(_ url: URL, atOrUnder root: URL) -> Bool {
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath().path
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        return candidate == rootPath || candidate.hasPrefix(rootPath + "/")
    }

    /// `NSPathControlItem.url` is read-only — items can't be hand-built with a custom URL, so
    /// this instead lets `NSPathControl` build its normal real-filesystem-hierarchy items from
    /// `url` (keeping every item's own URL intact for `onItemClicked`), then trims off whatever
    /// ancestor items sit above `root` and renames the one that IS `root` to its clean
    /// user-facing title. Needed because some macOS versions render the real, nested,
    /// Apple-internal iCloud Drive path as two consecutive "iCloud Drive"-titled breadcrumb
    /// segments (an ancestor folder aliased to that name, then the real one) when handed to
    /// `NSPathControl` directly — this collapses that (and any other unwanted ancestor chain
    /// above a known root) down to a single, correctly-named node.
    private func collapseAncestors(above root: (title: String, root: URL)) {
        let items = pathControl.pathItems
        let rootPath = root.root.standardizedFileURL.resolvingSymlinksInPath().path
        guard let rootIndex = items.firstIndex(where: { item in
            guard let itemURL = item.url else { return false }
            return itemURL.standardizedFileURL.resolvingSymlinksInPath().path == rootPath
        }) else { return }

        let trimmed = Array(items[rootIndex...])
        trimmed.first?.title = root.title
        pathControl.pathItems = trimmed
    }

}
#endif
