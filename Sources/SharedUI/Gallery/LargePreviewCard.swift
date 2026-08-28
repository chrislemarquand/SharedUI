#if os(macOS)
import AppKit
import SwiftUI

/// Flexible-size sibling of `InspectorPreviewCard` — for a large, primary preview pane (e.g. the
/// big-image half of a Finder-style Gallery View) rather than a fixed-height inspector column.
public struct LargePreviewCard: View {
    let image: NSImage?
    let isLoading: Bool
    let cornerRadius: CGFloat

    public init(image: NSImage?, isLoading: Bool, cornerRadius: CGFloat = InspectorMetrics.previewCardRadius) {
        self.image = image
        self.isLoading = isLoading
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}
#endif
