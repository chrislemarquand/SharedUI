import SwiftUI

public struct InspectorSectionContainer<Content: View>: View {
    let title: String
    let isExpanded: Binding<Bool>
    let content: Content

    public init(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.content = content()
    }

    public var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(InspectorMetrics.sectionInnerPadding)
                .background(
                    RoundedRectangle(cornerRadius: InspectorMetrics.sectionCardRadius, style: .continuous)
                        .fill(.quaternary.opacity(0.35))
                )
        } label: {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accentColor)
                .tracking(InspectorMetrics.sectionHeaderTracking)
        }
        .padding(.horizontal, InspectorMetrics.horizontalPadding)
    }
}
