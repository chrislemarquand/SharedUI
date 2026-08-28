import SwiftUI

/// A standard empty / loading state view used in place of content.
/// Wraps `ContentUnavailableView` so both apps stay visually consistent.
///
/// - `isLoading: false` (default)   — shows the symbol, title, and optional description
/// - `isLoading: true`             — shows the symbol, title, and an indeterminate progress bar
/// - `actionTitle` + `action`      — adds a standard button in the actions slot
/// - `isPerformingAction: true`    — replaces that button with a progress bar in the same slot,
///   for an action whose own completion (not just `isLoading`'s content-loading state) is what's
///   pending — e.g. "Download Now" turning into download progress. Determinate when
///   `actionProgress` (0...1) is supplied, indeterminate otherwise.
public struct PlaceholderView: View {
    let symbolName: String
    let title: String
    let description: String?
    let isLoading: Bool
    let actionTitle: String?
    let action: (() -> Void)?
    let isPerformingAction: Bool
    let actionProgress: Double?

    public init(
        symbolName: String,
        title: String,
        description: String? = nil,
        isLoading: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        isPerformingAction: Bool = false,
        actionProgress: Double? = nil
    ) {
        self.symbolName = symbolName
        self.title = title
        self.description = description
        self.isLoading = isLoading
        self.actionTitle = actionTitle
        self.action = action
        self.isPerformingAction = isPerformingAction
        self.actionProgress = actionProgress
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
            if isPerformingAction {
                Group {
                    if let actionProgress {
                        ProgressView(value: actionProgress)
                    } else {
                        ProgressView()
                    }
                }
                .progressViewStyle(.linear)
                .controlSize(.small)
                .frame(width: 120)
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
    }
}
