import AppKit
import SwiftUI

private struct InspectorRatingFlagActionPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct InspectorRatingFlagActionHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var inspectorRatingFlagActionIsPressed: Bool {
        get { self[InspectorRatingFlagActionPressedKey.self] }
        set { self[InspectorRatingFlagActionPressedKey.self] = newValue }
    }

    var inspectorRatingFlagActionIsHovered: Bool {
        get { self[InspectorRatingFlagActionHoveredKey.self] }
        set { self[InspectorRatingFlagActionHoveredKey.self] = newValue }
    }
}

private struct InspectorRatingFlagActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InspectorRatingFlagActionButton(configuration: configuration)
    }

    private struct InspectorRatingFlagActionButton: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .environment(\.inspectorRatingFlagActionIsPressed, configuration.isPressed)
                .environment(\.inspectorRatingFlagActionIsHovered, isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

public struct InspectorRatingFlagView: View {
    public let rating: Int
    public let ratingPending: Bool
    public let ratingEnabled: Bool
    public let onRatingChange: (Int) -> Void

    public let pick: Int
    public let pickPending: Bool
    public let pickEnabled: Bool
    public let onPickChange: (Int) -> Void

    public let label: String
    public let labelPending: Bool
    public let labelEnabled: Bool
    public let onLabelChange: (String) -> Void
    @State private var isLabelHovered = false
    @State private var isLabelPressed = false

    public init(
        rating: Int, ratingPending: Bool, ratingEnabled: Bool, onRatingChange: @escaping (Int) -> Void,
        pick: Int, pickPending: Bool, pickEnabled: Bool, onPickChange: @escaping (Int) -> Void,
        label: String, labelPending: Bool, labelEnabled: Bool, onLabelChange: @escaping (String) -> Void
    ) {
        self.rating = rating
        self.ratingPending = ratingPending
        self.ratingEnabled = ratingEnabled
        self.onRatingChange = onRatingChange
        self.pick = pick
        self.pickPending = pickPending
        self.pickEnabled = pickEnabled
        self.onPickChange = onPickChange
        self.label = label
        self.labelPending = labelPending
        self.labelEnabled = labelEnabled
        self.onLabelChange = onLabelChange
    }

    public var body: some View {
        if ratingEnabled || pickEnabled || labelEnabled {
            HStack(spacing: 14) {
                if ratingEnabled {
                    ratingRow
                }
                if pickEnabled {
                    pickButton
                }
                if labelEnabled {
                    labelMenu
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, InspectorMetrics.horizontalPadding)
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    onRatingChange(rating == n ? 0 : n)
                } label: {
                    InspectorRatingFlagSymbolLabel(
                        symbolName: n <= rating ? "star.fill" : "star",
                        pending: ratingPending
                    )
                }
                .buttonStyle(InspectorRatingFlagActionButtonStyle())
            }
        }
    }

    private var pickButton: some View {
        Button {
            let next: Int
            switch pick {
            case 0:  next = 1
            case 1:  next = -1
            default: next = 0
            }
            onPickChange(next)
        } label: {
            InspectorRatingFlagSymbolLabel(symbolName: pickSymbol, pending: pickPending)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(InspectorRatingFlagActionButtonStyle())
    }

    private var pickSymbol: String {
        switch pick {
        case 1:  return "flag.fill"
        case -1: return "flag.slash.fill"
        default: return "flag"
        }
    }

    private var labelMenu: some View {
        Menu {
            Button { onLabelChange("") } label: {
                Label { Text("None") } icon: { noneCircleImage() }
            }
            Divider()
            Button { onLabelChange("Red") }    label: { Label { Text("Red")    } icon: { colorCircleImage(.systemRed)    } }
            Button { onLabelChange("Yellow") } label: { Label { Text("Yellow") } icon: { colorCircleImage(.systemYellow) } }
            Button { onLabelChange("Green") }  label: { Label { Text("Green")  } icon: { colorCircleImage(.systemGreen)  } }
            Button { onLabelChange("Blue") }   label: { Label { Text("Blue")   } icon: { colorCircleImage(.systemBlue)   } }
            Button { onLabelChange("Purple") } label: { Label { Text("Purple") } icon: { colorCircleImage(.systemPurple) } }
        } label: {
            labelIndicator
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in
            isLabelHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isLabelPressed = true
                }
                .onEnded { _ in
                    isLabelPressed = false
                }
        )
    }

    @ViewBuilder
    private var labelIndicator: some View {
        ZStack {
            if label.isEmpty {
                noneCircleImage(
                    size: 16,
                    strokeColor: labelPending ? NSColor.systemOrange : NSColor.secondaryLabelColor
                )
            } else {
                colorCircleImage(
                    nsLabelColor,
                    size: 16
                )
                if labelPending {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(width: 22, height: 22)
    }

    private var nsLabelColor: NSColor {
        switch label {
        case "Red":    return .systemRed
        case "Yellow": return .systemYellow
        case "Green":  return .systemGreen
        case "Blue":   return .systemBlue
        case "Purple": return .systemPurple
        default:       return .clear
        }
    }

    private func colorCircleImage(_ nsColor: NSColor, size: CGFloat = 14) -> Image {
        let cgSize = CGSize(width: size, height: size)
        let nsImage = NSImage(size: cgSize, flipped: false) { rect in
            nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        nsImage.isTemplate = false
        return Image(nsImage: nsImage)
    }

    private func noneCircleImage(size: CGFloat = 14, strokeColor: NSColor = .secondaryLabelColor) -> Image {
        let cgSize = CGSize(width: size, height: size)
        let nsImage = NSImage(size: cgSize, flipped: false) { rect in
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            let path = NSBezierPath(ovalIn: inset)
            path.lineWidth = 1.5
            path.setLineDash([2.5, 2], count: 2, phase: 0)
            strokeColor.setStroke()
            path.stroke()
            return true
        }
        nsImage.isTemplate = false
        return Image(nsImage: nsImage)
    }
}

private struct InspectorRatingFlagSymbolLabel: View {
    let symbolName: String
    let pending: Bool
    @Environment(\.inspectorRatingFlagActionIsPressed) private var isPressed
    @Environment(\.inspectorRatingFlagActionIsHovered) private var isHovered

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 14))
            .foregroundStyle(symbolColor)
    }

    private var symbolColor: Color {
        if pending {
            if isPressed {
                return Color(nsColor: NSColor.systemOrange.withSystemEffect(.pressed))
            }
            if isHovered {
                return Color(nsColor: NSColor.systemOrange.withSystemEffect(.rollover))
            }
            return .orange
        }

        if isPressed {
            return Color.primary.opacity(0.7)
        }
        if isHovered {
            return .primary
        }
        return .secondary
    }
}
