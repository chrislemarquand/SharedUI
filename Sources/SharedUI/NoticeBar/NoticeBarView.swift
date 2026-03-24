import SwiftUI

/// A single-line notice bar with an optional primary and secondary button.
/// Intended to be hosted in an AppKit `NSHostingView` via `NoticeBar`.
public struct NoticeBarView: View {
    @Bindable var state: NoticeBarState

    public init(state: NoticeBarState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(state.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            if let secondary = state.secondaryAction {
                Button(secondary.title) {
                    secondary.handler()
                }
                .controlSize(.small)
            }

            if let primary = state.primaryAction {
                Button(primary.title) {
                    primary.handler()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
