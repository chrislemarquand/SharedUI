#if os(macOS)
import AppKit

public enum GalleryOverlayPosition: Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

@MainActor
@discardableResult
public func makeGalleryOverlaySymbol(
    in container: NSView,
    symbolName: String,
    tintColor: NSColor,
    position: GalleryOverlayPosition,
    size: CGFloat,
    inset: CGFloat
) -> NSImageView {
    let overlay = NSImageView(frame: .zero)
    overlay.translatesAutoresizingMaskIntoConstraints = false
    overlay.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    overlay.contentTintColor = tintColor
    container.addSubview(overlay)

    var constraints: [NSLayoutConstraint] = [
        overlay.widthAnchor.constraint(equalToConstant: size),
        overlay.heightAnchor.constraint(equalToConstant: size),
    ]
    switch position {
    case .topLeading:
        constraints.append(overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset))
        constraints.append(overlay.topAnchor.constraint(equalTo: container.topAnchor, constant: inset))
    case .topTrailing:
        constraints.append(overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset))
        constraints.append(overlay.topAnchor.constraint(equalTo: container.topAnchor, constant: inset))
    case .bottomLeading:
        constraints.append(overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset))
        constraints.append(overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset))
    case .bottomTrailing:
        constraints.append(overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset))
        constraints.append(overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset))
    }
    NSLayoutConstraint.activate(constraints)
    return overlay
}
#endif
