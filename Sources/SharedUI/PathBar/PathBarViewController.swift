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
    public static let preferredHeight: CGFloat = 24

    /// The path to display. Set to `nil` to show `placeholderString`.
    public var url: URL? {
        didSet { pathControl.url = url }
    }

    /// Displayed when `url` is `nil`.
    public var placeholderString: String = "" {
        didSet { pathControl.placeholderString = placeholderString }
    }

    /// Called when the user clicks a path component. The argument is the
    /// clicked component's URL.
    public var onItemClicked: ((URL) -> Void)?

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
        pathControl.translatesAutoresizingMaskIntoConstraints = false
        pathControl.action = #selector(pathControlClicked(_:))
        pathControl.target = self
        view.addSubview(pathControl)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: view.topAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            pathControl.topAnchor.constraint(equalTo: separator.bottomAnchor),
            pathControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            pathControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            pathControl.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func pathControlClicked(_ sender: NSPathControl) {
        guard let url = sender.clickedPathItem?.url else { return }
        onItemClicked?(url)
    }
}
