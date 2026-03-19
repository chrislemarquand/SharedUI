import SwiftUI

public struct InspectorHeaderView<Actions: View>: View {
    let title: String
    let subtitle: String?
    let actions: Actions

    public init(title: String, subtitle: String?, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: InspectorMetrics.headerTitleSpacing) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
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
    init(title: String, subtitle: String?) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}
