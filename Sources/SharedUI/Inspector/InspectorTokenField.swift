import AppKit
import SwiftUI

/// A styled keyword token field matching the inspector's text field appearance.
/// Return is the only tokenising character — comma is treated as literal within
/// a keyword so that "Smith, John" is preserved as a single token.
public struct InspectorTokenField: View {
    @Binding var text: String
    var placeholder: String
    var suggestions: [String]

    public init(
        text: Binding<String>,
        placeholder: String = "",
        suggestions: [String] = []
    ) {
        self._text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
    }

    public var body: some View {
        TokenFieldRepresentable(text: $text, placeholder: placeholder, suggestions: suggestions)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
    }
}

// MARK: - Representable

private struct TokenFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var suggestions: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> AutoSizingTokenField {
        let field = AutoSizingTokenField()
        field.tokenizingCharacterSet = .newlines
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.setTokens(in: field, from: text)
        return field
    }

    func updateNSView(_ field: AutoSizingTokenField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if !context.coordinator.isEditing {
            context.coordinator.setTokens(in: field, from: text)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTokenFieldDelegate {
        var parent: TokenFieldRepresentable
        var isEditing = false

        init(parent: TokenFieldRepresentable) {
            self.parent = parent
        }

        func setTokens(in field: AutoSizingTokenField, from string: String) {
            let tokens = Self.tokens(from: string)
            if (field.objectValue as? [String]) != tokens {
                field.objectValue = tokens
                field.invalidateIntrinsicContentSize()
            }
        }

        static func tokens(from string: String) -> [String] {
            string.isEmpty ? [] : string
                .components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        static func string(from field: NSTokenField) -> String {
            ((field.objectValue as? [String]) ?? []).joined(separator: ", ")
        }

        private func commit(from field: AutoSizingTokenField) {
            let newText = Self.string(from: field)
            if newText != parent.text {
                parent.text = newText
            }
        }

        // MARK: NSTokenFieldDelegate

        func tokenField(
            _ tokenField: NSTokenField,
            completionsForSubstring substring: String,
            indexOfToken tokenIndex: Int,
            indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?
        ) -> [Any]? {
            guard !substring.isEmpty else { return nil }
            let lower = substring.lowercased()
            return parent.suggestions.filter { $0.lowercased().hasPrefix(lower) }
        }

        func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            tokens
        }

        // MARK: NSControlTextEditingDelegate

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? AutoSizingTokenField else { return }
            field.invalidateIntrinsicContentSize()
            commit(from: field)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? AutoSizingTokenField else { return }
            field.invalidateIntrinsicContentSize()
            commit(from: field)
        }
    }
}

// MARK: - Auto-sizing subclass

private final class AutoSizingTokenField: NSTokenField {
    override var intrinsicContentSize: NSSize {
        CGSize(width: NSView.noIntrinsicMetric, height: fittingSize.height)
    }
}
