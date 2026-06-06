import SwiftUI

public struct NoticeBarView: View {
    @Bindable var state: NoticeBarState
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    private var isActive: Bool { controlActiveState != .inactive }
    #else
    private var isActive: Bool { true }
    #endif

    public init(state: NoticeBarState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(state.message)
                .font(.system(size: 12))
                .foregroundStyle(secondaryLabel)
                .lineLimit(1)
                .padding(.leading, 8)

            Spacer()

            if let secondary = state.secondaryAction {
                Button(secondary.title) {
                    secondary.handler()
                }
                .buttonStyle(.bordered)
                .tint(isActive ? secondaryLabel : tertiaryLabel)
                .controlSize(.small)
            }

            if let primary = state.primaryAction {
                if isActive {
                    Button(primary.title) {
                        primary.handler()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.small)
                } else {
                    Button(primary.title) {
                        primary.handler()
                    }
                    .buttonStyle(.bordered)
                    .tint(tertiaryLabel)
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

    private var secondaryLabel: Color {
        #if os(macOS)
        Color(nsColor: .secondaryLabelColor)
        #else
        Color(uiColor: .secondaryLabel)
        #endif
    }

    private var tertiaryLabel: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(uiColor: .tertiaryLabel)
        #endif
    }
}
