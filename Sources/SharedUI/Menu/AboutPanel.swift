#if os(macOS)
import AppKit

public struct AboutPanelCredit: Sendable {
    public let text: String
    public let linkURL: String?

    public init(text: String, linkURL: String? = nil) {
        self.text = text
        self.linkURL = linkURL
    }
}

@MainActor
public func showAboutPanel(
    purpose: String,
    credits: [AboutPanelCredit] = [],
    copyright: String? = nil
) {
    let bundle = Bundle.main
    let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? ProcessInfo.processInfo.processName
    let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"

    let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    let color = NSColor.secondaryLabelColor
    let centred = NSMutableParagraphStyle()
    centred.alignment = .center
    let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: centred,
    ]

    let body = NSMutableAttributedString(string: purpose, attributes: baseAttributes)

    for credit in credits {
        body.append(NSAttributedString(string: "\n\n\(credit.text)", attributes: baseAttributes))
        if let urlString = credit.linkURL {
            body.append(NSAttributedString(string: "\n", attributes: baseAttributes))
            let linkRange = NSRange(location: body.length, length: (urlString as NSString).length)
            body.append(NSAttributedString(string: urlString, attributes: baseAttributes))
            body.addAttributes(
                [
                    .link: urlString,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ],
                range: linkRange
            )
        }
    }

    var options: [NSApplication.AboutPanelOptionKey: Any] = [
        .applicationName: appName,
        .applicationVersion: shortVersion,
        .credits: body,
    ]
    if let copyright {
        options[NSApplication.AboutPanelOptionKey(rawValue: "Copyright")] = copyright
    }

    NSApp.orderFrontStandardAboutPanel(options: options)
    NSApp.activate(ignoringOtherApps: true)
}
#endif
