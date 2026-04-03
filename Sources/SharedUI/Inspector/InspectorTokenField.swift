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

    func makeNSView(context: Context) -> NSTokenField {
        let field = NSTokenField()
        field.tokenizingCharacterSet = .newlines
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        // Remove all AppKit chrome so the SwiftUI background/overlay show through.
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        // The CA layer paints its own white background even when drawsBackground = false.
        // Force it transparent explicitly.
        field.wantsLayer = true
        field.layer?.backgroundColor = NSColor.clear.cgColor
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        context.coordinator.setTokens(in: field, from: text)
        // KVO catches token deletions that don't fire controlTextDidChange
        // (e.g. click-select a token then Delete key goes via deleteBackward:).
        field.addObserver(context.coordinator, forKeyPath: "objectValue", options: .new, context: nil)
        return field
    }

    func updateNSView(_ field: NSTokenField, context: Context) {
        // Re-clear in case AppKit reinstates a layer background after hierarchy attachment.
        field.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.parent = self
        field.placeholderString = placeholder
        if !context.coordinator.isEditing {
            context.coordinator.setTokens(in: field, from: text)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTokenField, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, let cell = nsView.cell else { return nil }
        let height = cell.cellSize(
            forBounds: NSRect(x: 0, y: 0, width: width, height: 10_000)
        ).height
        return CGSize(width: width, height: height)
    }

    static func dismantleNSView(_ nsView: NSTokenField, coordinator: Coordinator) {
        nsView.removeObserver(coordinator, forKeyPath: "objectValue")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTokenFieldDelegate {
        var parent: TokenFieldRepresentable
        var isEditing = false
        // Prevents KVO re-entrancy when we programmatically set objectValue in setTokens.
        private var isSettingTokens = false

        init(parent: TokenFieldRepresentable) {
            self.parent = parent
        }

        func setTokens(in field: NSTokenField, from string: String) {
            let tokens = Self.tokens(from: string)
            guard (field.objectValue as? [String]) != tokens else { return }
            isSettingTokens = true
            field.objectValue = tokens
            isSettingTokens = false
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

        // MARK: KVO — catches token deletions that bypass controlTextDidChange

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard keyPath == "objectValue",
                  !isSettingTokens,
                  let field = object as? NSTokenField else { return }
            commit(from: field)
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
            guard let field = obj.object as? NSTokenField else { return }
            commit(from: field)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? NSTokenField else { return }
            commit(from: field)
        }
    }
}
