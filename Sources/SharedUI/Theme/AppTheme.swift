import AppKit
import SwiftUI

public enum AppTheme {
    /// The app accent colour, respecting the user's system accent override.
    /// NSAccentColorName in each app's Info.plist ensures this returns the
    /// app-specific colour (teal/red) in Multicolor mode, and the system
    /// override colour when the user has chosen a specific accent in System Settings.
    public static var accentNSColor: NSColor { .controlAccentColor }
    public static var accentColor: Color { Color(nsColor: accentNSColor) }
}
