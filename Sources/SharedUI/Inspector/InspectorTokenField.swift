import SwiftUI

/// A keyword token field styled to match the inspector's text fields.
/// Return is the only tokenising character so "Smith, John" is preserved as one token.
/// Chips render in the app accent colour. The field grows vertically as tokens wrap.
public struct InspectorTokenField: View {
    @Binding var text: String
    var placeholder: String

    @State private var inputText = ""
    @State private var inputFocused = false

    public init(
        text: Binding<String>,
        placeholder: String = ""
    ) {
        self._text = text
        self.placeholder = placeholder
    }

    // MARK: - Derived state

    private var tokens: [String] {
        guard !text.isEmpty else { return [] }
        return text
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Actions

    private func addCurrentInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tokens
        if !updated.contains(trimmed) { updated.append(trimmed) }
        text = updated.joined(separator: ", ")
        inputText = ""
    }

    private func remove(at index: Int) {
        var updated = tokens
        guard updated.indices.contains(index) else { return }
        updated.remove(at: index)
        text = updated.joined(separator: ", ")
    }

    // MARK: - Body

    public var body: some View {
        let currentTokens = tokens

        TokenFlowLayout(spacing: 4) {
            ForEach(Array(currentTokens.enumerated()), id: \.element) { index, token in
                TokenChip(token: token) {
                    remove(at: index)
                }
            }
            KeywordInputField(
                text: $inputText,
                placeholder: currentTokens.isEmpty ? placeholder : "",
                isFocused: $inputFocused,
                onCommit: addCurrentInput,
                onDeleteBackward: {
                    guard !currentTokens.isEmpty else { return }
                    remove(at: currentTokens.count - 1)
                }
            )
            .frame(minWidth: 44)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        // RoundedFieldBackground renders a real NSTextField bezel spanning the whole
        // chip-container, giving the correct adaptive appearance inside NSVisualEffectView.
        // The KeywordInputField inside is borderless; this is its visual frame.
        .background(
            RoundedFieldBackground()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

// MARK: - Rounded field background

/// Renders a real NSTextField bezel across the entire chip-container so the
/// adaptive grey appearance inside NSVisualEffectView matches other inspector fields.
/// sizeThatFits returns exactly the proposed size — the parent always proposes a
/// concrete size, so there is no estimation instability.
private struct RoundedFieldBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: "")
        field.isEditable = false
        field.isSelectable = false
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.fittingSize.width,
            height: proposal.height ?? nsView.fittingSize.height
        )
    }
}

