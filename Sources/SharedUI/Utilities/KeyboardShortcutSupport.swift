import AppKit

@MainActor
public enum KeyboardShortcutSupport {
    public static func canHandleWindowShortcuts(in window: NSWindow?) -> Bool {
        guard let window else { return false }
        if NSApp.modalWindow != nil { return false }
        if window.attachedSheet != nil { return false }
        guard let keyWindow = NSApp.keyWindow else { return false }
        return keyWindow === window
    }

    public static func responderOwningView(_ responder: NSResponder?) -> NSView? {
        if let view = responder as? NSView {
            return view
        }
        if let textView = responder as? NSTextView {
            if let delegateView = textView.delegate as? NSView {
                return delegateView
            }
            return textView.superview
        }
        return nil
    }

    public static func isEditableTextResponder(_ responder: NSResponder?) -> Bool {
        guard let textView = responder as? NSTextView else { return false }
        return textView.isEditable
    }

    public static func isResponder(_ responder: NSResponder?, inside rootView: NSView) -> Bool {
        guard let responderView = responderOwningView(responder) else { return false }
        return responderView === rootView || responderView.isDescendant(of: rootView)
    }

    public static func shouldHandlePaneTabSwitch(
        in window: NSWindow?,
        sidebarView: NSView,
        contentView: NSView
    ) -> Bool {
        guard let window else { return false }
        guard canHandleWindowShortcuts(in: window) else { return false }
        guard !isEditableTextResponder(window.firstResponder) else { return false }
        let inSidebar = isResponder(window.firstResponder, inside: sidebarView)
        let inContent = isResponder(window.firstResponder, inside: contentView)
        return inSidebar || inContent
    }

    public static func togglePaneFocus(
        in window: NSWindow?,
        sidebarView: NSView,
        contentView: NSView,
        focusSidebar: () -> Void,
        focusContent: () -> Void
    ) {
        guard let window else { return }
        let inSidebar = isResponder(window.firstResponder, inside: sidebarView)
        if inSidebar {
            focusContent()
            return
        }

        let inContent = isResponder(window.firstResponder, inside: contentView)
        if inContent {
            focusSidebar()
        }
    }
}
