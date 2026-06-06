#if os(macOS)
import AppKit

@MainActor
public final class GallerySelectionAppearanceObserver {
    private weak var hostView: NSView?
    private let onAppearanceChange: @MainActor () -> Void
    private var windowDidBecomeKeyObserver: NSObjectProtocol?
    private var windowDidResignKeyObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    private var appDidResignActiveObserver: NSObjectProtocol?
    private var appAppearanceObservation: NSKeyValueObservation?
    private var systemColorsObserver: NSObjectProtocol?

    public init(hostView: NSView, onAppearanceChange: @escaping @MainActor () -> Void) {
        self.hostView = hostView
        self.onAppearanceChange = onAppearanceChange
    }

    public func start() {
        guard windowDidBecomeKeyObserver == nil,
              windowDidResignKeyObserver == nil,
              appDidBecomeActiveObserver == nil,
              appDidResignActiveObserver == nil,
              appAppearanceObservation == nil else {
            return
        }
        guard let window = hostView?.window else { return }

        let center = NotificationCenter.default
        windowDidBecomeKeyObserver = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }
        windowDidResignKeyObserver = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }
        appDidBecomeActiveObserver = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }
        appDidResignActiveObserver = center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }

        appAppearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }

        // Fires when the user changes the system accent colour in System Settings.
        systemColorsObserver = center.addObserver(
            forName: NSColor.systemColorsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.onAppearanceChange() }
        }
    }

    public func stop() {
        let center = NotificationCenter.default
        if let windowDidBecomeKeyObserver {
            center.removeObserver(windowDidBecomeKeyObserver)
            self.windowDidBecomeKeyObserver = nil
        }
        if let windowDidResignKeyObserver {
            center.removeObserver(windowDidResignKeyObserver)
            self.windowDidResignKeyObserver = nil
        }
        if let appDidBecomeActiveObserver {
            center.removeObserver(appDidBecomeActiveObserver)
            self.appDidBecomeActiveObserver = nil
        }
        if let appDidResignActiveObserver {
            center.removeObserver(appDidResignActiveObserver)
            self.appDidResignActiveObserver = nil
        }
        appAppearanceObservation?.invalidate()
        appAppearanceObservation = nil
        if let systemColorsObserver {
            center.removeObserver(systemColorsObserver)
            self.systemColorsObserver = nil
        }
    }
}
#endif
