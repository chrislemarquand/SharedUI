import AppKit
import SwiftUI

/// An AppKit-backed text field for keyword entry.
///
/// Replaces the SwiftUI `TextField` + `RoundedFieldBackground` pair in
/// `InspectorTokenField`. Using a real `NSTextField` gives the correct
/// adaptive bezel natively, the system focus ring, and direct access to
/// the text-input trait flags that SwiftUI modifiers cannot reach.
public struct KeywordInputField: NSViewRepresentable {
    @Binding private var text: String
    private let placeholder: String
    @Binding private var isFocused: Bool
    private let onCommit: () -> Void
    private let onDeleteBackward: () -> Void

    public init(
        text: Binding<String>,
        placeholder: String,
        isFocused: Binding<Bool>,
        onCommit: @escaping () -> Void,
        onDeleteBackward: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        _isFocused = isFocused
        self.onCommit = onCommit
        self.onDeleteBackward = onDeleteBackward
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> ContainerView {
        let field = NSTextField(frame: .zero)
        // Borderless: the containing InspectorTokenField provides the outer bezel.
        field.isBezeled = false
        field.drawsBackground = false
        field.stringValue = text
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // isAutomaticTextCompletionEnabled lives on NSTextField — suppress the
        // system completion panel that appears on first focus.
        field.isAutomaticTextCompletionEnabled = false
        // The outer InspectorTokenField container draws its own focus ring across
        // the full chip area, so suppress the per-field system ring.
        field.focusRingType = .none
        // The remaining text-input flags (spell check, smart punctuation, etc.)
        // live on NSTextView (the shared field editor). They are set in
        // controlTextDidBeginEditing once the editor is active.

        return ContainerView(field: field)
    }

    public func updateNSView(_ nsView: ContainerView, context: Context) {
        context.coordinator.parent = self
        let field = nsView.field
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        if field.stringValue != text {
            context.coordinator.isProgrammaticUpdate = true
            field.stringValue = text
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, NSTextFieldDelegate {
        fileprivate var parent: KeywordInputField
        fileprivate var isProgrammaticUpdate = false

        fileprivate init(parent: KeywordInputField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard !isProgrammaticUpdate,
                  let field = obj.object as? NSTextField
            else { return }
            parent.text = field.stringValue
        }

        public func controlTextDidBeginEditing(_ obj: Notification) {
            parent.isFocused = true
            // The shared field editor is an NSTextView. Configure it here so
            // keywords are never mangled by smart punctuation, spell-check
            // underlines, or text substitutions.
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
            parent.isFocused = false
        }

        public func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)),
               let field = control as? NSTextField,
               field.stringValue.isEmpty {
                parent.onDeleteBackward()
                return true
            }
            return false
        }
    }

    // MARK: - ContainerView

    public final class ContainerView: NSView {
        let field: NSTextField

        init(field: NSTextField) {
            self.field = field
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: leadingAnchor),
                field.trailingAnchor.constraint(equalTo: trailingAnchor),
                field.topAnchor.constraint(equalTo: topAnchor),
                field.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: field.fittingSize.height)
        }
    }
}
