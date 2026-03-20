import AppKit
import SwiftUI

public struct InspectorPreviewCard<Overlay: View>: View {
    let image: NSImage?
    let isLoading: Bool
    let overlay: Overlay

    public init(image: NSImage?, isLoading: Bool, @ViewBuilder overlay: () -> Overlay) {
        self.image = image
        self.isLoading = isLoading
        self.overlay = overlay()
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: InspectorMetrics.previewCardRadius, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        overlay
                    }
            } else {
                RoundedRectangle(cornerRadius: InspectorMetrics.previewCardRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.22))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: InspectorMetrics.previewCardHeight)
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

public extension InspectorPreviewCard where Overlay == EmptyView {
    init(image: NSImage?, isLoading: Bool) {
        self.init(image: image, isLoading: isLoading) { EmptyView() }
    }
}
