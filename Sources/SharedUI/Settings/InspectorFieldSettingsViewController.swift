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
    private let contentStack = NSStackView()

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
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16

        contentView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -48),
        ])

        scrollView.documentView = contentView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func rebuildContent() {
        fieldByButtonID.removeAll()
        sectionByButtonID.removeAll()
        sectionToggleBySection.removeAll()
        fieldTogglesBySection.removeAll()
        sectionForFieldID.removeAll()

        for arranged in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }

        for section in sectionsProvider() {
            let sectionToggle = NSButton(
                checkboxWithTitle: section.title,
                target: self,
                action: #selector(sectionToggled(_:))
            )
            sectionToggle.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            sectionToggle.translatesAutoresizingMaskIntoConstraints = false

            let enabledCount = section.fields.reduce(into: 0) { partial, field in
                if field.isEnabled { partial += 1 }
            }
            sectionToggle.allowsMixedState = true
            if enabledCount == 0 {
                sectionToggle.state = .off
            } else if enabledCount == section.fields.count {
                sectionToggle.state = .on
            } else {
                sectionToggle.state = .mixed
            }

            sectionByButtonID[ObjectIdentifier(sectionToggle)] = section.title
            sectionToggleBySection[section.title] = sectionToggle

            let fieldStack = NSStackView()
            fieldStack.orientation = .vertical
            fieldStack.alignment = .leading
            fieldStack.spacing = 8
            fieldStack.translatesAutoresizingMaskIntoConstraints = false

            var togglesForSection: [NSButton] = []
            for field in section.fields {
                let fieldToggle = NSButton(
                    checkboxWithTitle: field.label,
                    target: self,
                    action: #selector(fieldToggled(_:))
                )
                fieldToggle.state = field.isEnabled ? .on : .off
                fieldToggle.translatesAutoresizingMaskIntoConstraints = false
                fieldByButtonID[ObjectIdentifier(fieldToggle)] = field.id
                sectionForFieldID[field.id] = section.title
                togglesForSection.append(fieldToggle)
                fieldStack.addArrangedSubview(fieldToggle)
            }
            fieldTogglesBySection[section.title] = togglesForSection

            let sectionGroup = NSStackView(views: [sectionToggle, fieldStack])
            sectionGroup.orientation = .vertical
            sectionGroup.alignment = .leading
            sectionGroup.spacing = 8
            sectionGroup.translatesAutoresizingMaskIntoConstraints = false
            sectionGroup.setCustomSpacing(6, after: sectionToggle)
            fieldStack.leadingAnchor.constraint(equalTo: sectionGroup.leadingAnchor, constant: 20).isActive = true
            contentStack.addArrangedSubview(sectionGroup)
        }
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
