#if os(macOS)
import AppKit
import SwiftUI

public struct InspectorDatePickerField: NSViewRepresentable {
    @Binding private var selection: Date
    private let isEnabled: Bool
    private let minimumDate: Date?
    private let maximumDate: Date?
    private let datePickerElements: NSDatePicker.ElementFlags
    private let datePickerStyle: NSDatePicker.Style
    private let accessibilityLabel: String?

    public init(
        selection: Binding<Date>,
        isEnabled: Bool = true,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        datePickerElements: NSDatePicker.ElementFlags = [.yearMonthDay, .hourMinute],
        datePickerStyle: NSDatePicker.Style = .textFieldAndStepper,
        accessibilityLabel: String? = nil
    ) {
        _selection = selection
        self.isEnabled = isEnabled
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.datePickerElements = datePickerElements
        self.datePickerStyle = datePickerStyle
        self.accessibilityLabel = accessibilityLabel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let picker = NSDatePicker(frame: .zero)
        picker.datePickerMode = .single
        picker.datePickerStyle = datePickerStyle
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.didChangeDate(_:))
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let container = ContainerView(control: picker)
        return container
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let picker = nsView.datePicker
        picker.isEnabled = isEnabled
        picker.minDate = minimumDate
        picker.maxDate = maximumDate
        picker.datePickerElements = datePickerElements
        picker.datePickerStyle = datePickerStyle
        if let accessibilityLabel {
            picker.setAccessibilityLabel(accessibilityLabel)
        }

        if abs(picker.dateValue.timeIntervalSince(selection)) > 0.001 {
            context.coordinator.isProgrammaticUpdate = true
            picker.dateValue = selection
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    public final class Coordinator: NSObject {
        fileprivate var parent: InspectorDatePickerField
        fileprivate var isProgrammaticUpdate = false

        fileprivate init(parent: InspectorDatePickerField) {
            self.parent = parent
        }

        @MainActor @objc fileprivate func didChangeDate(_ sender: NSDatePicker) {
            guard !isProgrammaticUpdate else { return }
            let next = sender.dateValue
            guard abs(next.timeIntervalSince(parent.selection)) > 0.001 else { return }
            parent.selection = next
        }
    }

    public final class ContainerView: NSView {
        let datePicker: NSDatePicker

        init(control: NSDatePicker) {
            datePicker = control
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
            let controlSize = datePicker.intrinsicContentSize
            return NSSize(width: NSView.noIntrinsicMetric, height: controlSize.height)
        }
    }
}
#endif
