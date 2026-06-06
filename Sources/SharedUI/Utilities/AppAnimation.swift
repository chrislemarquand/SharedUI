#if os(macOS)
import AppKit
import QuartzCore
import SwiftUI

/// Standard animation timing for UI transitions across all SharedUI apps.
public enum Motion {
    public static let duration: Double = 0.16
    public static var timingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(name: .easeInEaseOut)
    }
}

/// Returns the standard app animation, or nil when the user has enabled
/// Reduce Motion in Accessibility settings.
public func appAnimation() -> Animation? {
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        return nil
    }
    return .easeInOut(duration: Motion.duration)
}
#endif
