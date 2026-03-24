import SwiftUI

/// A standard empty / loading state view used in place of content.
/// Wraps `ContentUnavailableView` so both apps stay visually consistent.
///
/// - `isLoading: false` (default) — shows the symbol, title, and optional description
/// - `isLoading: true`           — shows the symbol, title, and an indeterminate progress bar
/// - `actionTitle` + `action`    — adds a standard button in the actions slot
public struct PlaceholderView: View {
    let symbolName: String
    let title: String
    let description: String?
    let isLoading: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        symbolName: String,
        title: String,
        description: String? = nil,
        isLoading: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbolName = symbolName
        self.title = title
        self.description = description
        self.isLoading = isLoading
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .frame(width: 220)
            } else if let description {
                Text(description)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
    }
}
