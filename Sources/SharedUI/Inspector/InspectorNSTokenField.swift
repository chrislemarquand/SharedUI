#if os(macOS)
import AppKit
import SwiftUI

/// AppKit-backed keyword token field for the inspector.
///
/// Wraps `NSTokenField` to provide native chip display, backspace-to-delete-last-token,
/// correct appearance inside NSVisualEffectView, and smart-text suppression — none of
/// which are achievable from SwiftUI TextField.
///
/// **Tokenising character:** Return only. Commas are valid inside keyword values
/// and are NOT used as separators.
///
/// **Storage format:** The `text` binding stores keywords as a comma-separated
/// string: `"keyword1, keyword2, keyword3"`. This matches the existing XMP/IPTC
/// storage format used throughout the app.
public struct InspectorNSTokenField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let tagID: String
    var onClearAll: (() -> Void)?
    let onFocusChange: (Bool) -> Void
    let onEscape: () -> Void
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        tagID: String,
        onClearAll: (() -> Void)? = nil,
        onFocusChange: @escaping (Bool) -> Void,
        onEscape: @escaping () -> Void,
        onTab: (() -> Void)? = nil,
        onShiftTab: (() -> Void)? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.tagID = tagID
        self.onClearAll = onClearAll
        self.onFocusChange = onFocusChange
        self.onEscape = onEscape
        self.onTab = onTab
        self.onShiftTab = onShiftTab
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let field = NSTokenField(frame: .zero)
        // Return only — commas are valid in keyword values
        field.tokenizingCharacterSet = CharacterSet(charactersIn: "\r")
        field.isAutomaticTextCompletionEnabled = false
        field.focusRingType = .default
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.tokenStyle = .rounded
        field.objectValue = tokens(from: text)
        field.placeholderString = placeholder

        let container = ContainerView(
            field: field,
            coordinator: context.coordinator,
            hasClearAll: onClearAll != nil
        )
        context.coordinator.container = container
        context.coordinator.registerFocusObserver()
        return container
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let field = nsView.tokenField

        let current = Self.tokenString(from: field.objectValue as? [String] ?? [])
        if current != text {
            context.coordinator.isProgrammaticUpdate = true
            field.objectValue = tokens(from: text)
            context.coordinator.isProgrammaticUpdate = false
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        context.coordinator.clearAllAction = onClearAll
        nsView.updateClearAllVisibility(hasTokens: !tokens(from: text).isEmpty)
    }

    // MARK: - Helpers

    private func tokens(from string: String) -> [String] {
        guard !string.isEmpty else { return [] }
        return string
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    fileprivate static func tokenString(from tokens: [String]) -> String {
        tokens.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, NSTokenFieldDelegate, NSTextFieldDelegate {
        fileprivate var parent: InspectorNSTokenField
        fileprivate var isProgrammaticUpdate = false
        fileprivate weak var container: ContainerView?
        fileprivate var clearAllAction: (() -> Void)?

        fileprivate init(parent: InspectorNSTokenField) {
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
                let field = container?.tokenField
            else { return }
            field.window?.makeFirstResponder(field)
        }

        // MARK: NSTextFieldDelegate

        public func controlTextDidChange(_ obj: Notification) {
            guard !isProgrammaticUpdate,
                  let field = obj.object as? NSTokenField
            else { return }
            let tokens = (field.objectValue as? [String] ?? []).filter { !$0.isEmpty }
            let newText = InspectorNSTokenField.tokenString(from: tokens)
            if newText != parent.text {
                parent.text = newText
            }
            container?.updateClearAllVisibility(hasTokens: !tokens.isEmpty)
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
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            parent.onFocusChange(false)
        }

        public func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
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

        @objc fileprivate func clearAllButtonPressed() {
            clearAllAction?()
            container?.tokenField.objectValue = []
            container?.updateClearAllVisibility(hasTokens: false)
        }
    }

    // MARK: - ContainerView

    public final class ContainerView: NSView {
        let tokenField: NSTokenField
        private let clearAllButton: NSButton?
        private var trackingArea: NSTrackingArea?
        private var isHovered = false

        init(field: NSTokenField, coordinator: Coordinator, hasClearAll: Bool) {
            tokenField = field

            var clearBtn: NSButton? = nil
            if hasClearAll {
                let btn = NSButton(frame: .zero)
                btn.isBordered = false
                btn.bezelStyle = .regularSquare
                btn.image = NSImage(
                    systemSymbolName: "xmark.circle.fill",
                    accessibilityDescription: nil
                )
                btn.imageScaling = .scaleProportionallyDown
                btn.contentTintColor = .secondaryLabelColor
                btn.isHidden = true
                btn.translatesAutoresizingMaskIntoConstraints = false
                btn.target = coordinator
                btn.action = #selector(Coordinator.clearAllButtonPressed)
                btn.setAccessibilityLabel("Clear all keywords")
                btn.setAccessibilityRole(.button)
                clearBtn = btn
            }
            clearAllButton = clearBtn

            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)

            var constraints: [NSLayoutConstraint] = [
                field.topAnchor.constraint(equalTo: topAnchor),
                field.bottomAnchor.constraint(equalTo: bottomAnchor),
                field.leadingAnchor.constraint(equalTo: leadingAnchor),
                field.trailingAnchor.constraint(equalTo: trailingAnchor),
            ]

            if let btn = clearBtn {
                addSubview(btn)
                constraints += [
                    btn.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -4),
                    btn.centerYAnchor.constraint(equalTo: field.centerYAnchor),
                    btn.widthAnchor.constraint(equalToConstant: 16),
                    btn.heightAnchor.constraint(equalToConstant: 16),
                ]
            }

            NSLayoutConstraint.activate(constraints)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        public override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: tokenField.intrinsicContentSize.height)
        }

        public override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea { removeTrackingArea(existing) }
            guard clearAllButton != nil else { return }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
            // Correct hover state when the view scrolls out from under the cursor.
            let mouseInWindow = window?.mouseLocationOutsideOfEventStream ?? .zero
            if !bounds.contains(convert(mouseInWindow, from: nil)), isHovered {
                isHovered = false
                updateClearAllVisibility(hasTokens: !(tokenField.objectValue as? [String] ?? []).isEmpty)
            }
        }

        public override func mouseEntered(with event: NSEvent) {
            isHovered = true
            updateClearAllVisibility(hasTokens: !(tokenField.objectValue as? [String] ?? []).isEmpty)
        }

        public override func mouseExited(with event: NSEvent) {
            isHovered = false
            updateClearAllVisibility(hasTokens: !(tokenField.objectValue as? [String] ?? []).isEmpty)
        }

        fileprivate func updateClearAllVisibility(hasTokens: Bool) {
            clearAllButton?.isHidden = !(hasTokens && isHovered)
        }
    }
}
#endif
