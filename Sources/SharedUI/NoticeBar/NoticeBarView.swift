import SwiftUI

/// A single-line notice bar with an optional primary and secondary button.
/// Intended to be hosted in an AppKit `NSHostingView` via `NoticeBar`.
public struct NoticeBarView: View {
    @Bindable var state: NoticeBarState
    @Environment(\.controlActiveState) private var controlActiveState

    public init(state: NoticeBarState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(state.message)
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
                .padding(.leading, 8)

            Spacer()

            if let secondary = state.secondaryAction {
                Button(secondary.title) {
                    secondary.handler()
                }
                .buttonStyle(.bordered)
                .tint(controlActiveState == .inactive ? Color(nsColor: .tertiaryLabelColor) : Color(nsColor: .secondaryLabelColor))
                .controlSize(.small)
            }

            if let primary = state.primaryAction {
                if controlActiveState == .inactive {
                    Button(primary.title) {
                        primary.handler()
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(nsColor: .tertiaryLabelColor))
                    .controlSize(.small)
                } else {
                    Button(primary.title) {
                        primary.handler()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.small)
                }
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
