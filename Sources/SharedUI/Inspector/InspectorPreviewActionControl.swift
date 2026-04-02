import SwiftUI

private struct InspectorPreviewActionPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct InspectorPreviewActionHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var inspectorPreviewActionIsPressed: Bool {
        get { self[InspectorPreviewActionPressedKey.self] }
        set { self[InspectorPreviewActionPressedKey.self] = newValue }
    }

    var inspectorPreviewActionIsHovered: Bool {
        get { self[InspectorPreviewActionHoveredKey.self] }
        set { self[InspectorPreviewActionHoveredKey.self] = newValue }
    }
}

public struct InspectorPreviewActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        InspectorPreviewActionButton(configuration: configuration)
    }

    private struct InspectorPreviewActionButton: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .environment(\.inspectorPreviewActionIsPressed, configuration.isPressed)
                .environment(\.inspectorPreviewActionIsHovered, isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

public struct InspectorPreviewActionLabel: View {
    let symbolName: String
    let title: String
    @Environment(\.inspectorPreviewActionIsPressed) private var isPressed
    @Environment(\.inspectorPreviewActionIsHovered) private var isHovered

    public init(symbolName: String, title: String) {
        self.symbolName = symbolName
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(isPressed ? Color.primary.opacity(0.7) : (isHovered ? Color.primary : Color.secondary))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
