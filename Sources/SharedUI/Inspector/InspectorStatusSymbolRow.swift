import SwiftUI

public struct InspectorStatusSymbolRow: View {
    public struct Item: Identifiable, Hashable {
        public let id: String
        public let symbolName: String
        public let accessibilityLabel: String
        public let toolTip: String

        public init(id: String, symbolName: String, accessibilityLabel: String, toolTip: String) {
            self.id = id
            self.symbolName = symbolName
            self.accessibilityLabel = accessibilityLabel
            self.toolTip = toolTip
        }
    }

    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    Image(systemName: item.symbolName)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .accessibilityLabel(item.accessibilityLabel)
                        .help(item.toolTip)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, InspectorMetrics.horizontalPadding)
        }
    }
}
