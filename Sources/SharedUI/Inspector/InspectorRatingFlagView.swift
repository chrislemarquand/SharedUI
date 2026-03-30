import AppKit
import SwiftUI

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
            HStack(spacing: 12) {
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
                    Image(systemName: n <= rating ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(ratingPending ? Color.orange : Color.primary)
                }
                .buttonStyle(.plain)
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
            Image(systemName: pickSymbol)
                .font(.system(size: 14))
                .foregroundStyle(pickPending ? Color.orange : Color.primary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
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
                Label {
                    Text("None")
                } icon: {
                    Image(systemName: "circle.dotted")
                }
            }
            Divider()
            Button { onLabelChange("Red") }    label: { Label { Text("Red")    } icon: { colorCircleImage(.red)    } }
            Button { onLabelChange("Yellow") } label: { Label { Text("Yellow") } icon: { colorCircleImage(.yellow) } }
            Button { onLabelChange("Green") }  label: { Label { Text("Green")  } icon: { colorCircleImage(.green)  } }
            Button { onLabelChange("Blue") }   label: { Label { Text("Blue")   } icon: { colorCircleImage(.blue)   } }
            Button { onLabelChange("Purple") } label: { Label { Text("Purple") } icon: { colorCircleImage(.purple) } }
        } label: {
            labelIndicator
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func colorCircleImage(_ nsColor: NSColor) -> Image {
        let size = CGSize(width: 14, height: 14)
        let nsImage = NSImage(size: size, flipped: false) { rect in
            nsColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        nsImage.isTemplate = false
        return Image(nsImage: nsImage)
    }

    @ViewBuilder
    private var labelIndicator: some View {
        ZStack {
            if label.isEmpty {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 16))
                    .foregroundStyle(labelPending ? Color.orange : Color.secondary)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(labelColor)
                if labelPending {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.orange)
                }
            }
        }
        .frame(width: 22, height: 22)
    }

    private var labelColor: Color {
        switch label {
        case "Red":    return .red
        case "Yellow": return .yellow
        case "Green":  return .green
        case "Blue":   return .blue
        case "Purple": return .purple
        default:       return .clear
        }
    }
}
