import SwiftUI

/// A standard empty / loading state view used in place of content.
/// Wraps `ContentUnavailableView` so both apps stay visually consistent.
///
/// - `isLoading: false` (default) — shows the symbol, title, and optional description
/// - `isLoading: true`           — shows the symbol, title, and a ProgressView spinner
public struct PlaceholderView: View {
    let symbolName: String
    let title: String
    let description: String?
    let isLoading: Bool

    public init(
        symbolName: String,
        title: String,
        description: String? = nil,
        isLoading: Bool = false
    ) {
        self.symbolName = symbolName
        self.title = title
        self.description = description
        self.isLoading = isLoading
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if let description {
                Text(description)
            }
        }
    }
}
