import AppKit
import SwiftUI
import WhatsNewKit

// MARK: - Feature descriptor

public struct AppWelcomeFeature {
    public let symbolName: String
    public let title: String
    public let subtitle: String

    public init(symbolName: String, title: String, subtitle: String) {
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - View controller

/// An `NSViewController` that presents a WhatsNewKit welcome screen.
/// Apps control "show once" logic themselves — this controller always displays.
/// Present it as a sheet on the main window.
@MainActor
public final class AppWelcomeViewController: NSHostingController<AnyView> {

    public init(
        appName: String,
        features: [AppWelcomeFeature],
        primaryButtonTitle: String = "Get Started",
        secondaryButtonTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let whatsNew = WhatsNew(
            title: WhatsNew.Title(stringLiteral: "Welcome to \(appName)"),
            features: features.map { f in
                WhatsNew.Feature(
                    image: .init(
                        systemName: f.symbolName,
                        foregroundColor: .accentColor
                    ),
                    title: WhatsNew.Text(stringLiteral: f.title),
                    subtitle: WhatsNew.Text(stringLiteral: f.subtitle)
                )
            },
            primaryAction: .init(
                title: WhatsNew.Text(stringLiteral: primaryButtonTitle),
                onDismiss: onDismiss
            ),
            secondaryAction: secondaryButtonTitle.map { title in
                WhatsNew.SecondaryAction(
                    title: WhatsNew.Text(stringLiteral: title),
                    action: .custom { _ in
                        onSecondaryAction?()
                    }
                )
            }
        )

        let view = WhatsNewView(whatsNew: whatsNew)
        super.init(rootView: AnyView(view))
        preferredContentSize = CGSize(width: 540, height: 660)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
