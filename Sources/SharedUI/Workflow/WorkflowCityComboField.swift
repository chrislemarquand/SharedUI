import AppKit
import SwiftUI

// MARK: - Timezone City Data

public enum TimeZoneCityData {
    public static let cities: [(city: String, identifier: String)] = {
        let skipPrefixes = ["Etc/", "US/", "Canada/", "Mexico/", "Brazil/", "Chile/",
                            "SystemV/", "GMT", "UCT", "UTC", "Universal", "Zulu",
                            "CET", "CST6CDT", "EET", "EST", "EST5EDT", "HST",
                            "MET", "MST", "MST7MDT", "PST8PDT", "WET",
                            "PRC", "ROC", "ROK", "NZ", "NZ-CHAT",
                            "W-SU", "Kwajalein", "Navajo", "Libya", "Egypt",
                            "Eire", "GB", "GB-Eire", "Greenwich", "Hongkong",
                            "Iceland", "Iran", "Israel", "Jamaica", "Japan",
                            "Poland", "Portugal", "Singapore", "Turkey", "Cuba"]
        return TimeZone.knownTimeZoneIdentifiers
            .filter { id in
                guard id.contains("/") else { return false }
                return !skipPrefixes.contains(where: { id.hasPrefix($0) })
            }
            .compactMap { id -> (String, String)? in
                guard let lastComponent = id.split(separator: "/").last else { return nil }
                let city = String(lastComponent).replacingOccurrences(of: "_", with: " ")
                guard !city.isEmpty else { return nil }
                return (city, id)
            }
            .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }()

    public static func identifier(forCity city: String) -> String? {
        cities.first { $0.city.caseInsensitiveCompare(city) == .orderedSame }?.identifier
    }

    public static func city(forIdentifier identifier: String) -> String? {
        cities.first { $0.identifier == identifier }?.city
    }
}

// MARK: - Combo Field

public struct WorkflowCityComboField: NSViewRepresentable {
    @Binding private var value: String
    private let items: [String]
    private let placeholder: String
    private let isEnabled: Bool

    public init(
        value: Binding<String>,
        items: [String],
        placeholder: String = "",
        isEnabled: Bool = true
    ) {
        _value = value
        self.items = items
        self.placeholder = placeholder
        self.isEnabled = isEnabled
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let comboBox = NSComboBox(frame: .zero)
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.hasVerticalScroller = true
        comboBox.numberOfVisibleItems = 12
        comboBox.translatesAutoresizingMaskIntoConstraints = false
        comboBox.setContentHuggingPriority(.defaultLow, for: .horizontal)
        comboBox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.comboBoxAction(_:))
        let container = ContainerView(control: comboBox)
        return container
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let comboBox = nsView.comboBox
        comboBox.isEnabled = isEnabled
        comboBox.placeholderString = placeholder

        if context.coordinator.lastItems != items {
            context.coordinator.isProgrammaticUpdate = true
            comboBox.removeAllItems()
            comboBox.addItems(withObjectValues: items)
            context.coordinator.lastItems = items
            context.coordinator.isProgrammaticUpdate = false
        }

        if comboBox.stringValue != value {
            context.coordinator.isProgrammaticUpdate = true
            comboBox.stringValue = value
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    // MARK: Coordinator

    public final class Coordinator: NSObject, NSComboBoxDelegate {
        fileprivate var parent: WorkflowCityComboField
        fileprivate var isProgrammaticUpdate = false
        fileprivate var lastItems: [String] = []

        fileprivate init(parent: WorkflowCityComboField) {
            self.parent = parent
        }

        @MainActor @objc fileprivate func comboBoxAction(_ sender: NSComboBox) {
            commitValue(sender)
        }

        public func comboBoxSelectionDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate,
                  let comboBox = notification.object as? NSComboBox else { return }
            DispatchQueue.main.async { [weak self] in
                self?.commitValue(comboBox)
            }
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            guard !isProgrammaticUpdate,
                  let comboBox = obj.object as? NSComboBox else { return }
            DispatchQueue.main.async { [weak self] in
                self?.commitValue(comboBox)
            }
        }

        @MainActor private func commitValue(_ comboBox: NSComboBox) {
            guard !isProgrammaticUpdate else { return }
            let newValue = comboBox.stringValue
            guard newValue != parent.value else { return }
            parent.value = newValue
        }
    }

    // MARK: ContainerView

    public final class ContainerView: NSView {
        let comboBox: NSComboBox

        init(control: NSComboBox) {
            comboBox = control
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(control)
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(equalTo: leadingAnchor),
                control.trailingAnchor.constraint(equalTo: trailingAnchor),
                control.topAnchor.constraint(equalTo: topAnchor),
                control.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override var intrinsicContentSize: NSSize {
            let controlSize = comboBox.intrinsicContentSize
            return NSSize(width: NSView.noIntrinsicMetric, height: controlSize.height)
        }
    }
}
