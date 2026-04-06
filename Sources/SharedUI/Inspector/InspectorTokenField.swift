import SwiftUI

public struct InspectorTokenField: View {
    @Binding var text: String
    var placeholder: String
    var onClearAll: (() -> Void)?

    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @State private var isHovered = false

    public init(
        text: Binding<String>,
        placeholder: String = "",
        onClearAll: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClearAll = onClearAll
    }

    // MARK: - Derived state

    private var tokens: [String] {
        guard !text.isEmpty else { return [] }
        return text
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var showClearButton: Bool {
        isHovered && !tokens.isEmpty && onClearAll != nil
    }

    // MARK: - Actions

    private func addCurrentInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tokens
        if !updated.contains(trimmed) { updated.append(trimmed) }
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
            text = updated.joined(separator: ", ")
        }
        inputText = ""
    }

    private func remove(at index: Int) {
        var updated = tokens
        guard updated.indices.contains(index) else { return }
        updated.remove(at: index)
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
            text = updated.joined(separator: ", ")
        }
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(tokens.isEmpty ? placeholder : "Add keyword\u{2026}", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit { addCurrentInput() }
                .focused($inputFocused)

            if !tokens.isEmpty {
                TokenFlowLayout(spacing: 4) {
                    ForEach(Array(tokens.enumerated()), id: \.element) { index, token in
                        TokenChip(token: token) {
                            remove(at: index)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .trailing) {
                    if showClearButton {
                        Button("Clear all keywords", systemImage: "xmark.circle.fill", action: onClearAll!)
                            .buttonStyle(.plain)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .help("Clear all keywords")
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.1), value: showClearButton)
            }
        }
        .onHover { isHovered = $0 }
    }
}
