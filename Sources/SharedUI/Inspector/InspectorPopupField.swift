#if os(macOS)
import AppKit
import SwiftUI

public struct InspectorPopupOption: Identifiable, Hashable, Sendable {
    public let value: String
    public let label: String

    public var id: String { value }

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public struct InspectorPopupField: NSViewRepresentable {
    @Binding private var selection: String
    private let options: [InspectorPopupOption]
    private let isEnabled: Bool
    private let accessibilityLabel: String?

    public init(
        selection: Binding<String>,
        options: [InspectorPopupOption],
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        _selection = selection
        self.options = options
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.didChangeSelection(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let container = ContainerView(control: popup)
        return container
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let popup = nsView.popupButton
        popup.isEnabled = isEnabled
        if let accessibilityLabel {
            popup.setAccessibilityLabel(accessibilityLabel)
        }

        if context.coordinator.lastOptions != options {
            context.coordinator.isProgrammaticUpdate = true
            popup.removeAllItems()
            for option in options {
                popup.addItem(withTitle: option.label)
                popup.lastItem?.representedObject = option.value
            }
            context.coordinator.lastOptions = options
            context.coordinator.isProgrammaticUpdate = false
        }

        let selectedIndex = options.firstIndex(where: { $0.value == selection }) ?? -1
        if popup.indexOfSelectedItem != selectedIndex {
            context.coordinator.isProgrammaticUpdate = true
            if selectedIndex >= 0 {
                popup.selectItem(at: selectedIndex)
            } else {
                popup.select(nil)
            }
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    public final class Coordinator: NSObject {
        fileprivate var parent: InspectorPopupField
        fileprivate var isProgrammaticUpdate = false
        fileprivate var lastOptions: [InspectorPopupOption] = []

        fileprivate init(parent: InspectorPopupField) {
            self.parent = parent
        }

        @MainActor @objc fileprivate func didChangeSelection(_ sender: NSPopUpButton) {
            guard !isProgrammaticUpdate else { return }
            let selectedValue = sender.selectedItem?.representedObject as? String ?? ""
            guard selectedValue != parent.selection else { return }
            parent.selection = selectedValue
        }
    }

    public final class ContainerView: NSView {
        let popupButton: NSPopUpButton

        init(control: NSPopUpButton) {
            popupButton = control
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
            let controlSize = popupButton.intrinsicContentSize
            return NSSize(width: NSView.noIntrinsicMetric, height: controlSize.height)
        }
    }
}
#endif
