import SwiftUI

/// A keyword token field styled to match the inspector's text fields.
/// Return is the only tokenising character so "Smith, John" is preserved as one token.
/// Chips render in the app accent colour. The field grows vertically as tokens wrap.
public struct InspectorTokenField: View {
    @Binding var text: String
    var placeholder: String
    var suggestions: [String]

    @State private var inputText = ""
    @State private var showSuggestions = false
    @State private var selectedTokenIndex: Int? = nil
    @FocusState private var inputFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        suggestions: [String] = []
    ) {
        self._text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
    }

    // MARK: - Derived state

    private var tokens: [String] {
        guard !text.isEmpty else { return [] }
        return text
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var filteredSuggestions: [String] {
        guard !inputText.isEmpty else { return [] }
        let lower = inputText.lowercased()
        return suggestions.filter {
            $0.lowercased().hasPrefix(lower) && !tokens.contains($0)
        }
    }

    // MARK: - Actions

    private func addCurrentInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = tokens
        if !updated.contains(trimmed) { updated.append(trimmed) }
        text = updated.joined(separator: ", ")
        inputText = ""
        showSuggestions = false
        selectedTokenIndex = nil
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
        let currentSuggestions = filteredSuggestions

        TokenFlowLayout(spacing: 4) {
            ForEach(currentTokens.enumerated(), id: \.offset) { index, token in
                TokenChip(token: token, isSelected: selectedTokenIndex == index) {
                    selectedTokenIndex = nil
                    remove(at: index)
                } onSelect: {
                    selectedTokenIndex = index
                    inputFocused = true
                }
            }
            TextField(currentTokens.isEmpty ? placeholder : "", text: $inputText)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .frame(minWidth: 44)
                .onSubmit(addCurrentInput)
                .onKeyPress(characters: .init(charactersIn: "\u{7f}")) { _ in
                    guard inputText.isEmpty else { return .ignored }
                    if let selected = selectedTokenIndex {
                        remove(at: selected)
                        selectedTokenIndex = nil
                    } else if !currentTokens.isEmpty {
                        selectedTokenIndex = currentTokens.count - 1
                    }
                    return .handled
                }
                .onChange(of: inputText) {
                    if !inputText.isEmpty { selectedTokenIndex = nil }
                    showSuggestions = inputFocused && !inputText.isEmpty && !currentSuggestions.isEmpty
                }
                .onChange(of: inputFocused) {
                    if !inputFocused {
                        showSuggestions = false
                        selectedTokenIndex = nil
                    }
                }
                .popover(isPresented: $showSuggestions, arrowEdge: .bottom) {
                    SuggestionList(suggestions: currentSuggestions) { suggestion in
                        inputText = suggestion
                        addCurrentInput()
                    }
                }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        // RoundedFieldBackground is a real NSTextField rendered in the AppKit/NSVisualEffectView
        // hierarchy, giving the correct adaptive grey that plain SwiftUI colours cannot replicate.
        // sizeThatFits returns the proposed size so it expands to match multi-row chip content.
        .background(
            RoundedFieldBackground()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .inset(by: -3)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .opacity(inputFocused ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: inputFocused)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Keywords field")
    }
}

// MARK: - Suggestion list

private struct SuggestionList: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { onSelect(suggestion) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minWidth: 160, maxHeight: 160)
    }
}

// MARK: - Token chip

private struct TokenChip: View {
    let token: String
    let isSelected: Bool
    let onRemove: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(token)
                .font(.caption)
            Button("Remove \(token)", systemImage: "xmark", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption)
                .fontWeight(.bold)
                .imageScale(.small)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.accentColor.opacity(isSelected ? 0.3 : 0.15)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(isSelected ? 0.7 : 0.35), lineWidth: isSelected ? 1 : 0.5))
        .foregroundStyle(Color.accentColor)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .simultaneousGesture(TapGesture().onEnded { onSelect() })
    }
}

// MARK: - Flow layout

private struct TokenFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(subviews: subviews, width: proposal.width ?? 0)
        guard !rows.isEmpty else { return CGSize(width: proposal.width ?? 0, height: 0) }
        let height = rows.map(\.height).reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let yOffset = (row.height - item.size.height) / 2
                item.subview.place(
                    at: CGPoint(x: x, y: y + yOffset),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct RowItem { let subview: LayoutSubview; let size: CGSize }

    private struct Row {
        var items: [RowItem] = []
        var height: CGFloat { items.map(\.size.height).max() ?? 0 }
    }

    private func computeRows(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let wouldOverflow = !rows.last!.items.isEmpty && rowWidth + size.width > width
            if wouldOverflow {
                rows.append(Row())
                rowWidth = 0
            }
            rows[rows.count - 1].items.append(RowItem(subview: subview, size: size))
            rowWidth += size.width + spacing
        }

        return rows.filter { !$0.items.isEmpty }
    }
}

// MARK: - Rounded field background

/// An NSTextField rendered purely for its bezel appearance inside the NSVisualEffectView
/// hierarchy. sizeThatFits accepts the proposed size so it fills the content bounds
/// at any height, unlike SwiftUI's TextField which enforces single-line intrinsic height.
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
        let naturalHeight = nsView.fittingSize.height
        return CGSize(
            width: proposal.width ?? nsView.fittingSize.width,
            height: max(proposal.height ?? naturalHeight, naturalHeight)
        )
    }
}
