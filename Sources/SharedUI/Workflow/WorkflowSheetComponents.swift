import SwiftUI

public struct WorkflowSheetSectionSpacing: Sendable {
    public let headerToTop: CGFloat
    public let topToMain: CGFloat
    public let mainToFooter: CGFloat

    public init(
        headerToTop: CGFloat,
        topToMain: CGFloat,
        mainToFooter: CGFloat
    ) {
        self.headerToTop = headerToTop
        self.topToMain = topToMain
        self.mainToFooter = mainToFooter
    }

    public static func uniform(_ value: CGFloat) -> WorkflowSheetSectionSpacing {
        WorkflowSheetSectionSpacing(
            headerToTop: value,
            topToMain: value,
            mainToFooter: value
        )
    }

    public static let `default`: WorkflowSheetSectionSpacing = .uniform(12)
}

public struct WorkflowSheetContainer<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let infoText: String?
    private let width: CGFloat
    private let sectionSpacing: WorkflowSheetSectionSpacing
    private let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        infoText: String? = nil,
        width: CGFloat = 580,
        sectionSpacing: WorkflowSheetSectionSpacing = .default,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.infoText = infoText
        self.width = width
        self.sectionSpacing = sectionSpacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                WorkflowSheetTitleRow(title: title, infoText: infoText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, sectionSpacing.headerToTop)
            content
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: width)
    }
}

public struct WorkflowSheetTitleRow: View {
    private let title: String
    private let infoText: String?
    @State private var showInfo = false

    public init(title: String, infoText: String? = nil) {
        self.title = title
        self.infoText = infoText
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let infoText {
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo) {
                    Text(infoText)
                        .font(.callout)
                        .padding()
                        .frame(minWidth: 260, maxWidth: 340)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

public struct WorkflowOptionGroup<Content: View>: View {
    private let title: String
    private let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
            content
        }
    }
}

public struct WorkflowInlineMessageBanner: View {
    private let messages: [String]

    public init(messages: [String]) {
        self.messages = messages
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(messages, id: \.self) { message in
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

public struct WorkflowFormRow<Label: View, Content: View>: View {
    private let label: Label
    private let labelWidth: CGFloat
    private let labelAlignment: Alignment
    private let rowMinHeight: CGFloat
    private let content: Content

    public init(
        _ label: String,
        labelWidth: CGFloat = 132,
        labelAlignment: Alignment = .trailing,
        rowMinHeight: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) where Label == Text {
        self.label = Text(label)
        self.labelWidth = labelWidth
        self.labelAlignment = labelAlignment
        self.rowMinHeight = rowMinHeight
        self.content = content()
    }

    public init(
        labelWidth: CGFloat = 132,
        labelAlignment: Alignment = .trailing,
        rowMinHeight: CGFloat = 28,
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label()
        self.labelWidth = labelWidth
        self.labelAlignment = labelAlignment
        self.rowMinHeight = rowMinHeight
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            label
                .frame(width: labelWidth, alignment: labelAlignment)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .leading)
    }
}

public struct WorkflowDetailsPopover: View {
    private let text: String
    private let width: CGFloat
    private let height: CGFloat

    public init(text: String, width: CGFloat = 560, height: CGFloat = 300) {
        self.text = text
        self.width = width
        self.height = height
    }

    public var body: some View {
        ScrollView {
            HStack(alignment: .top) {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }
}
