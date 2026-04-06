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
        view.preferredSize = size
        return view
    }

    public func updateNSView(_ nsView: ColourCircleView, context: Context) {
        // Always assign — NSColor object identity (===) is unreliable for dynamic
        // colours; circleColor.didSet calls needsDisplay so no separate trigger needed.
        nsView.circleColor = nsColor
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: ColourCircleView, context: Context) -> CGSize? {
        CGSize(width: size, height: size)
    }

    public final class ColourCircleView: NSView {
        var circleColor: NSColor = .clear {
            didSet { needsDisplay = true }
        }
        var preferredSize: CGFloat = 16

        public override var intrinsicContentSize: NSSize {
            NSSize(width: preferredSize, height: preferredSize)
        }

        public override func draw(_ dirtyRect: NSRect) {
            circleColor.setFill()
            NSBezierPath(ovalIn: bounds).fill()
        }
    }
}
