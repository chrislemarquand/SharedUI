import AppKit
import SwiftUI

// MARK: - Notification

public extension Notification.Name {
    /// Posted by InspectorTextField when it wants programmatic focus.
    /// userInfo["tagID"]: String
    static let inspectorDidRequestFieldFocus =
        Notification.Name("com.ledger.inspector.requestFieldFocus")
}

// MARK: - InspectorTextField

/// AppKit-backed inspector text field.
///
/// Provides correct adaptive appearance inside NSVisualEffectView, suppresses
/// the text completion panel flash, suppresses smart-text features on the field
/// editor, and shows a hover-reveal clear button — none of which are achievable
/// from a SwiftUI TextField.
public struct InspectorTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let fieldLabel: String
    let tagID: String
    var isEnabled: Bool
    let onFocusChange: (Bool) -> Void
    let onEscape: () -> Void
    var onCommit: (() -> Void)?
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var trailingAction: (label: String, action: () -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        fieldLabel: String,
        tagID: String,
        isEnabled: Bool = true,
        onFocusChange: @escaping (Bool) -> Void,
        onEscape: @escaping () -> Void,
        onCommit: (() -> Void)? = nil,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil,
        trailingAction: (label: String, action: () -> Void)? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.fieldLabel = fieldLabel
        self.tagID = tagID
        self.isEnabled = isEnabled
        self.onFocusChange = onFocusChange
        self.onEscape = onEscape
        self.onCommit = onCommit
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.trailingAction = trailingAction
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let field = NSTextField(frame: .zero)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.isEditable = true
        field.isSelectable = true
        field.isAutomaticTextCompletionEnabled = false
        field.focusRingType = .default
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.stringValue = text
        field.placeholderString = placeholder
        field.isEnabled = isEnabled

        let container = ContainerView(
            field: field,
            coordinator: context.coordinator,
            fieldLabel: fieldLabel,
            trailingAction: trailingAction
        )
        context.coordinator.container = container
        context.coordinator.registerFocusObserver()
        return container
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let field = nsView.textField

        if field.stringValue != text {
            context.coordinator.isProgrammaticUpdate = true
            field.stringValue = text
            context.coordinator.isProgrammaticUpdate = false
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        if field.isEnabled != isEnabled {
            field.isEnabled = isEnabled
        }
        context.coordinator.trailingAction = trailingAction?.action
        nsView.updateClearButtonVisibility()
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, NSTextFieldDelegate {
        fileprivate var parent: InspectorTextField
        fileprivate var isProgrammaticUpdate = false
        fileprivate weak var container: ContainerView?
        fileprivate var trailingAction: (() -> Void)?

        fileprivate init(parent: InspectorTextField) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(
                self,
                name: .inspectorDidRequestFieldFocus,
                object: nil
            )
        }

        fileprivate func registerFocusObserver() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleFocusRequest(_:)),
                name: .inspectorDidRequestFieldFocus,
                object: nil
            )
        }

        @objc private func handleFocusRequest(_ notification: Notification) {
            guard
                let requestedID = notification.userInfo?["tagID"] as? String,
                requestedID == parent.tagID,
                let field = container?.textField
            else { return }
            field.window?.makeFirstResponder(field)
        }

        // MARK: NSTextFieldDelegate

        public func controlTextDidChange(_ obj: Notification) {
            guard !isProgrammaticUpdate,
                  let field = obj.object as? NSTextField
            else { return }
            parent.text = field.stringValue
            container?.updateClearButtonVisibility()
        }

        public func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusChange(true)
            if let field = obj.object as? NSTextField,
               let textView = field.currentEditor() as? NSTextView {
                textView.isAutomaticSpellingCorrectionEnabled = false
                textView.isContinuousSpellCheckingEnabled = false
                textView.isAutomaticQuoteSubstitutionEnabled = false
                textView.isAutomaticDashSubstitutionEnabled = false
                textView.isAutomaticTextReplacementEnabled = false
                textView.isAutomaticLinkDetectionEnabled = false
            }
            container?.isEditing = true
            container?.updateClearButtonVisibility()
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            parent.onFocusChange(false)
            container?.isEditing = false
            container?.updateClearButtonVisibility()
        }

        public func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onCommit?()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                control.window?.makeFirstResponder(nil)
                return true
            case #selector(NSResponder.insertTab(_:)):
                if let onTab = parent.onTab {
                    onTab()
                    return true
                }
                return false
            case #selector(NSResponder.insertBacktab(_:)):
                if let onShiftTab = parent.onShiftTab {
                    onShiftTab()
                    return true
                }
                return false
            default:
                return false
            }
        }

        @objc fileprivate func clearButtonPressed() {
            parent.text = ""
            container?.textField.stringValue = ""
            container?.updateClearButtonVisibility()
        }

        @objc fileprivate func trailingButtonPressed() {
            trailingAction?()
        }
    }

    // MARK: - ContainerView

    public final class ContainerView: NSView {
        let textField: NSTextField
        private let clearButton: NSButton
        private(set) var trailingButton: NSButton?
        private var trackingArea: NSTrackingArea?
        fileprivate var isEditing = false
        private var isHovered = false

        init(
            field: NSTextField,
            coordinator: Coordinator,
            fieldLabel: String,
            trailingAction: (label: String, action: () -> Void)?
        ) {
            textField = field

            let clear = NSButton(frame: .zero)
            clear.isBordered = false
            clear.bezelStyle = .regularSquare
            clear.image = NSImage(
                systemSymbolName: "xmark.circle.fill",
                accessibilityDescription: nil
            )
            clear.imageScaling = .scaleProportionallyDown
            clear.contentTintColor = .secondaryLabelColor
            clear.isHidden = true
            clear.translatesAutoresizingMaskIntoConstraints = false
            clear.target = coordinator
            clear.action = #selector(Coordinator.clearButtonPressed)
            clear.setAccessibilityLabel("Clear \(fieldLabel)")
            clear.setAccessibilityRole(.button)
            clearButton = clear

            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
            addSubview(clear)

            var constraints: [NSLayoutConstraint] = [
                field.topAnchor.constraint(equalTo: topAnchor),
                field.bottomAnchor.constraint(equalTo: bottomAnchor),
                field.leadingAnchor.constraint(equalTo: leadingAnchor),
                // Clear button overlaid at trailing edge of the text field
                clear.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -4),
                clear.centerYAnchor.constraint(equalTo: field.centerYAnchor),
                clear.widthAnchor.constraint(equalToConstant: 16),
                clear.heightAnchor.constraint(equalToConstant: 16),
            ]

            if let action = trailingAction {
                let btn = NSButton(
                    title: action.label,
                    target: coordinator,
                    action: #selector(Coordinator.trailingButtonPressed)
                )
                btn.controlSize = .small
                btn.bezelStyle = .rounded
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.setAccessibilityLabel(action.label)
                addSubview(btn)
                trailingButton = btn
                coordinator.trailingAction = action.action
                constraints += [
                    field.trailingAnchor.constraint(equalTo: btn.leadingAnchor, constant: -6),
                    btn.trailingAnchor.constraint(equalTo: trailingAnchor),
                    btn.centerYAnchor.constraint(equalTo: centerYAnchor),
                ]
            } else {
                constraints.append(field.trailingAnchor.constraint(equalTo: trailingAnchor))
            }

            NSLayoutConstraint.activate(constraints)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        public override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: textField.intrinsicContentSize.height)
        }

        public override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea { removeTrackingArea(existing) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        public override func mouseEntered(with event: NSEvent) {
            isHovered = true
            updateClearButtonVisibility()
        }

        public override func mouseExited(with event: NSEvent) {
            isHovered = false
            updateClearButtonVisibility()
        }

        fileprivate func updateClearButtonVisibility() {
            let show = !textField.stringValue.isEmpty
                && (isHovered || isEditing)
                && textField.isEnabled
            clearButton.isHidden = !show
        }
    }
}
