#if os(macOS)
import AppKit

public enum PinchZoomStep: Sendable {
    case zoomIn
    case zoomOut
}

@MainActor
public final class PinchZoomAccumulator {
    public let threshold: CGFloat
    private var accumulatedDelta: CGFloat = 0
    private var lastMagnification: CGFloat = 0

    public init(threshold: CGFloat = 0.14) {
        self.threshold = threshold
    }

    public func reset() {
        accumulatedDelta = 0
        lastMagnification = 0
    }

    public func handle(_ gesture: NSMagnificationGestureRecognizer, onStep: (PinchZoomStep) -> Void) {
        switch gesture.state {
        case .began:
            reset()
        case .changed:
            let delta = gesture.magnification - lastMagnification
            lastMagnification = gesture.magnification
            accumulatedDelta += delta

            while accumulatedDelta >= threshold {
                onStep(.zoomIn)
                accumulatedDelta -= threshold
            }
            while accumulatedDelta <= -threshold {
                onStep(.zoomOut)
                accumulatedDelta += threshold
            }
        default:
            reset()
        }
    }
}
#endif
