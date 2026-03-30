import SwiftUI

public struct InspectorHeaderView<Actions: View>: View {
    let title: String
    let subtitle: String?
    let pendingChange: Bool
    let actions: Actions

    public init(title: String, subtitle: String?, pendingChange: Bool = false, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
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
            if let subtitle {
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
}
