import AppKit

public struct InspectorFieldSettingsField: Hashable {
    public let id: String
    public let label: String
    public let isEnabled: Bool

    public init(id: String, label: String, isEnabled: Bool) {
        self.id = id
        self.label = label
        self.isEnabled = isEnabled
    }
}

public struct InspectorFieldSettingsSection: Hashable {
    public let title: String
    public let fields: [InspectorFieldSettingsField]

    public init(title: String, fields: [InspectorFieldSettingsField]) {
        self.title = title
        self.fields = fields
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
public final class InspectorFieldSettingsViewController: NSViewController {
    private let sectionsProvider: () -> [InspectorFieldSettingsSection]
    private let onToggleSection: (String, Bool) -> Void
    private let onToggleField: (String, Bool) -> Void

    private let scrollView = NSScrollView()
    private let contentView = FlippedView()
    private var currentGrid: NSGridView?

    private var fieldByButtonID: [ObjectIdentifier: String] = [:]
    private var sectionByButtonID: [ObjectIdentifier: String] = [:]
    private var sectionToggleBySection: [String: NSButton] = [:]
    private var fieldTogglesBySection: [String: [NSButton]] = [:]
    private var sectionForFieldID: [String: String] = [:]

    public init(
        sectionsProvider: @escaping () -> [InspectorFieldSettingsSection],
        onToggleSection: @escaping (String, Bool) -> Void,
        onToggleField: @escaping (String, Bool) -> Void
    ) {
        self.sectionsProvider = sectionsProvider
        self.onToggleSection = onToggleSection
        self.onToggleField = onToggleField
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reload()
    }

    public func reload() {
        rebuildContent()
    }

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = contentView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func rebuildContent() {
        fieldByButtonID.removeAll()
        sectionByButtonID.removeAll()
        sectionToggleBySection.removeAll()
        fieldTogglesBySection.removeAll()
        sectionForFieldID.removeAll()

        currentGrid?.removeFromSuperview()
        currentGrid = nil

        let sections = sectionsProvider()
        guard !sections.isEmpty else { return }

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 6
        grid.columnSpacing = 16

        for (sectionIndex, section) in sections.enumerated() {
            // Gap row between sections for visual separation.
            if sectionIndex > 0 {
                let gapRow = grid.addRow(with: [NSGridCell.emptyContentView, NSGridCell.emptyContentView])
                gapRow.height = 8
            }

            // Section header — merged across both columns.
            let sectionToggle = NSButton(
                checkboxWithTitle: section.title,
                target: self,
                action: #selector(sectionToggled(_:))
            )
            sectionToggle.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            sectionToggle.translatesAutoresizingMaskIntoConstraints = false

            let enabledCount = section.fields.reduce(into: 0) { $0 += $1.isEnabled ? 1 : 0 }
            sectionToggle.allowsMixedState = true
            sectionToggle.state = enabledCount == 0 ? .off : (enabledCount == section.fields.count ? .on : .mixed)

            sectionByButtonID[ObjectIdentifier(sectionToggle)] = section.title
            sectionToggleBySection[section.title] = sectionToggle

            let headerRow = grid.addRow(with: [sectionToggle, NSGridCell.emptyContentView])
            headerRow.mergeCells(in: NSRange(location: 0, length: 2))

            // Field rows — two per row, left then right.
            // Left column is wrapped with a 20pt leading indent so field checkboxes
            // align with the section header's text label.
            var togglesForSection: [NSButton] = []
            var i = 0
            while i < section.fields.count {
                let left = makeFieldToggle(section.fields[i], sectionTitle: section.title)
                togglesForSection.append(left)
                let right: NSView
                if i + 1 < section.fields.count {
                    let r = makeFieldToggle(section.fields[i + 1], sectionTitle: section.title)
                    togglesForSection.append(r)
                    right = r
                } else {
                    right = NSGridCell.emptyContentView
                }
                grid.addRow(with: [indented(left), right])
                i += 2
            }
            fieldTogglesBySection[section.title] = togglesForSection
        }

        contentView.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
        currentGrid = grid
    }

    private func indented(_ view: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeFieldToggle(_ field: InspectorFieldSettingsField, sectionTitle: String) -> NSButton {
        let toggle = NSButton(checkboxWithTitle: field.label, target: self, action: #selector(fieldToggled(_:)))
        toggle.state = field.isEnabled ? .on : .off
        toggle.translatesAutoresizingMaskIntoConstraints = false
        fieldByButtonID[ObjectIdentifier(toggle)] = field.id
        sectionForFieldID[field.id] = sectionTitle
        return toggle
    }

    private func recalculateSectionToggleState(for section: String) {
        guard let sectionToggle = sectionToggleBySection[section],
              let toggles = fieldTogglesBySection[section] else { return }
        let enabledCount = toggles.reduce(into: 0) { count, toggle in
            if toggle.state == .on { count += 1 }
        }
        if enabledCount == 0 {
            sectionToggle.state = .off
        } else if enabledCount == toggles.count {
            sectionToggle.state = .on
        } else {
            sectionToggle.state = .mixed
        }
    }

    @objc private func sectionToggled(_ sender: NSButton) {
        guard let section = sectionByButtonID[ObjectIdentifier(sender)] else { return }
        let enable = sender.state != .off
        onToggleSection(section, enable)
        if let toggles = fieldTogglesBySection[section] {
            for toggle in toggles {
                toggle.state = enable ? .on : .off
            }
        }
        recalculateSectionToggleState(for: section)
    }

    @objc private func fieldToggled(_ sender: NSButton) {
        guard let fieldID = fieldByButtonID[ObjectIdentifier(sender)] else { return }
        onToggleField(fieldID, sender.state == .on)
        if let section = sectionForFieldID[fieldID] {
            recalculateSectionToggleState(for: section)
        }
    }
}
