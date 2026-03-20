import AppKit
import SwiftUI

public enum AppTheme {
    public static var accentNSColor: NSColor {
        NSColor(named: "AccentColor") ?? .controlAccentColor
    }
    public static var accentColor: Color { Color(nsColor: accentNSColor) }
}
