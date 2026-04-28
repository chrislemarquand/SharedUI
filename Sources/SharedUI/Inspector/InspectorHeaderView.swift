import SwiftUI

public struct InspectorHeaderView<Actions: View>: View {
    let title: String
    let subtitles: [String]
    let pendingChange: Bool
    let actions: Actions

    public init(title: String, subtitle: String?, pendingChange: Bool = false, @ViewBuilder actions: () -> Actions) {
        self.init(title: title, subtitles: subtitle.map { [$0] } ?? [], pendingChange: pendingChange, actions: actions)
    }

    public init(title: String, subtitles: [String], pendingChange: Bool = false, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitles = subtitles
        self.pendingChange = pendingChange
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: InspectorMetrics.headerTitleSpacing) {
            HStack(spacing: 6) {
                if pendingChange {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.orange)
                }
                Text(title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            ForEach(subtitles, id: \.self) { subtitle in
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, InspectorMetrics.horizontalPadding)
    }
}

public extension InspectorHeaderView where Actions == EmptyView {
    init(title: String, subtitle: String?, pendingChange: Bool = false) {
        self.init(title: title, subtitle: subtitle, pendingChange: pendingChange) { EmptyView() }
    }

    init(title: String, subtitles: [String], pendingChange: Bool = false) {
        self.init(title: title, subtitles: subtitles, pendingChange: pendingChange) { EmptyView() }
    }
}
