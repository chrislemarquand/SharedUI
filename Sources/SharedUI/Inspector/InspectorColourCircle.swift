import AppKit
import SwiftUI

/// A filled colour circle rendered in AppKit's drawing pipeline.
///
/// Unlike `Circle().fill(Color(nsColor))`, this view draws inside `NSView.draw(_:)`
/// where dynamic `NSColor` values (e.g. `.systemRed`) resolve correctly against
/// the current `NSAppearance`. SwiftUI's own render path resolves NSColors before
/// the correct appearance context is established, producing invisible fills.
public struct InspectorColourCircle: NSViewRepresentable {
    let nsColor: NSColor
    let size: CGFloat

    public init(nsColor: NSColor, size: CGFloat = 16) {
        self.nsColor = nsColor
        self.size = size
    }

    public func makeNSView(context: Context) -> ColourCircleView {
        let view = ColourCircleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size),
        ])
        return view
    }

    public func updateNSView(_ nsView: ColourCircleView, context: Context) {
        if nsView.circleColor !== nsColor {
            nsView.circleColor = nsColor
            nsView.needsDisplay = true
        }
    }

    public final class ColourCircleView: NSView {
        var circleColor: NSColor = .clear {
            didSet { needsDisplay = true }
        }

        public override var intrinsicContentSize: NSSize {
            bounds.isEmpty ? NSSize(width: 16, height: 16) : bounds.size
        }

        public override func draw(_ dirtyRect: NSRect) {
            circleColor.setFill()
            NSBezierPath(ovalIn: bounds).fill()
        }
    }
}
