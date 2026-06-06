import SwiftUI

#if os(macOS)
import AppKit
#endif

public enum AppTheme {
    #if os(macOS)
    public static var accentNSColor: NSColor { .controlAccentColor }
    public static var accentColor: Color { Color(nsColor: accentNSColor) }
    #else
    public static var accentColor: Color { .accentColor }
    #endif
}
