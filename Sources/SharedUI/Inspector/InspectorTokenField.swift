import AppKit
import SwiftUI

/// An NSTokenField wrapper that converts a comma-space separated string
/// to/from discrete tokens. Return is the only tokenising character —
/// comma is treated as a literal character within a keyword so that
/// keywords like "Smith, John" are preserved as a single token.
public struct InspectorTokenField: NSViewRepresentable {
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

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> NSTokenField {
        let field = NSTokenField()
        field.tokenizingCharacterSet = .newlines
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.setTokens(in: field, from: text)
        return field
    }

    public func updateNSView(_ field: NSTokenField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if !context.coordinator.isEditing {
            context.coordinator.setTokens(in: field, from: text)
        }
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, NSTokenFieldDelegate {
        var parent: InspectorTokenField
        var isEditing = false

        init(parent: InspectorTokenField) {
            self.parent = parent
        }

        func setTokens(in field: NSTokenField, from string: String) {
            let tokens = Self.tokens(from: string)
            if (field.objectValue as? [String]) != tokens {
                field.objectValue = tokens
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

        private func commit(from field: NSTokenField) {
            let newText = Self.string(from: field)
            if newText != parent.text {
                parent.text = newText
            }
        }

        // MARK: NSTokenFieldDelegate

        public func tokenField(
            _ tokenField: NSTokenField,
            completionsForSubstring substring: String,
            indexOfToken tokenIndex: Int,
            indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?
        ) -> [Any]? {
            guard !substring.isEmpty else { return nil }
            let lower = substring.lowercased()
            return parent.suggestions.filter { $0.lowercased().hasPrefix(lower) }
        }

        public func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            tokens
        }

        // MARK: NSControlTextEditingDelegate

        public func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTokenField else { return }
            commit(from: field)
        }

        public func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? NSTokenField else { return }
            commit(from: field)
        }
    }
}
