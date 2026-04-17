import AppKit

/// Returns a fully configured standard macOS app menu.
/// Assign as the submenu of the first NSMenuItem in NSApp.mainMenu.
///
/// - Parameters:
///   - appName: The localised display name shown in About, Hide, and Quit items.
///   - aboutAction: Selector for the About item. Defaults to the system About panel.
///   - settingsAction: Selector for Settings… (⌘,). Dispatched via the responder chain.
@MainActor
public func makeStandardAppMenu(
    appName: String,
    aboutAction: Selector = #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
    settingsAction: Selector,
    checkForUpdatesAction: Selector? = nil
) -> NSMenu {
    let menu = NSMenu(title: appName)

    let aboutItem = NSMenuItem(title: "About \(appName)", action: aboutAction, keyEquivalent: "")
    aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
    menu.addItem(aboutItem)
    menu.addItem(.separator())

    let settingsItem = NSMenuItem(title: "Settings…", action: settingsAction, keyEquivalent: ",")
    settingsItem.keyEquivalentModifierMask = .command
    settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
    menu.addItem(settingsItem)

    if let checkForUpdatesAction {
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: checkForUpdatesAction,
            keyEquivalent: ""
        )
        checkForUpdatesItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(checkForUpdatesItem)
    }

    menu.addItem(.separator())

    let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
    let servicesMenu = NSMenu(title: "Services")
    servicesItem.submenu = servicesMenu
    NSApp.servicesMenu = servicesMenu
    menu.addItem(servicesItem)
    menu.addItem(.separator())

    let hideItem = NSMenuItem(
        title: "Hide \(appName)",
        action: #selector(NSApplication.hide(_:)),
        keyEquivalent: "h"
    )
    hideItem.keyEquivalentModifierMask = .command
    menu.addItem(hideItem)

    let hideOthersItem = NSMenuItem(
        title: "Hide Others",
        action: #selector(NSApplication.hideOtherApplications(_:)),
        keyEquivalent: "h"
    )
    hideOthersItem.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(hideOthersItem)

    menu.addItem(NSMenuItem(
        title: "Show All",
        action: #selector(NSApplication.unhideAllApplications(_:)),
        keyEquivalent: ""
    ))
    menu.addItem(.separator())

    let quitItem = NSMenuItem(
        title: "Quit \(appName)",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    quitItem.keyEquivalentModifierMask = .command
    menu.addItem(quitItem)

    return menu
}

/// Returns a fully configured standard Window menu.
/// After adding its wrapper NSMenuItem to NSApp.mainMenu, assign the
/// returned menu to NSApp.windowsMenu so AppKit manages open windows automatically.
@MainActor
public func makeStandardWindowMenu() -> NSMenu {
    let menu = NSMenu(title: "Window")

    let minimizeItem = NSMenuItem(
        title: "Minimize",
        action: #selector(NSWindow.miniaturize(_:)),
        keyEquivalent: "m"
    )
    minimizeItem.keyEquivalentModifierMask = .command
    menu.addItem(minimizeItem)

    menu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(
        title: "Bring All to Front",
        action: #selector(NSApplication.arrangeInFront(_:)),
        keyEquivalent: ""
    ))

    return menu
}
