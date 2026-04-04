import SwiftUI

struct TokenChip: View {
    let token: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(token)
                .font(.caption)
            Button("Remove \(token)", systemImage: "xmark", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption)
                .fontWeight(.bold)
                .imageScale(.small)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.5))
        .foregroundStyle(Color.accentColor)
    }
}
