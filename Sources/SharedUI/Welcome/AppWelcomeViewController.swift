#if os(macOS)
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

public struct AppWelcomePresentation: Identifiable {
    public let id = UUID()
    public let appName: String
    public let features: [AppWelcomeFeature]
    public let primaryButtonTitle: String
    public let secondaryButtonTitle: String?
    public let onPrimaryAction: (() -> Void)?
    public let onSecondaryAction: (() -> Void)?

    public init(
        appName: String,
        features: [AppWelcomeFeature],
        primaryButtonTitle: String = "Get Started",
        secondaryButtonTitle: String? = nil,
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.appName = appName
        self.features = features
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }
}

public struct AppWelcomeSheetView: View {
    private let presentation: AppWelcomePresentation

    public init(presentation: AppWelcomePresentation) {
        self.presentation = presentation
    }

    public var body: some View {
        WhatsNewView(whatsNew: makeWhatsNew())
            .frame(width: 540, height: 660)
    }

    private func makeWhatsNew() -> WhatsNew {
        WhatsNew(
            title: WhatsNew.Title(stringLiteral: "Welcome to \(presentation.appName)"),
            features: presentation.features.map { feature in
                WhatsNew.Feature(
                    image: .init(
                        systemName: feature.symbolName,
                        foregroundColor: .accentColor
                    ),
                    title: WhatsNew.Text(stringLiteral: feature.title),
                    subtitle: WhatsNew.Text(stringLiteral: feature.subtitle)
                )
            },
            primaryAction: .init(
                title: WhatsNew.Text(stringLiteral: presentation.primaryButtonTitle),
                onDismiss: presentation.onPrimaryAction
            ),
            secondaryAction: presentation.secondaryButtonTitle.map { title in
                WhatsNew.SecondaryAction(
                    title: WhatsNew.Text(stringLiteral: title),
                    action: .custom { _ in
                        presentation.onSecondaryAction?()
                    }
                )
            }
        )
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
        let presentation = AppWelcomePresentation(
            appName: appName,
            features: features,
            primaryButtonTitle: primaryButtonTitle,
            secondaryButtonTitle: secondaryButtonTitle,
            onPrimaryAction: onDismiss,
            onSecondaryAction: onSecondaryAction
        )
        super.init(rootView: AnyView(AppWelcomeSheetView(presentation: presentation)))
        preferredContentSize = CGSize(width: 540, height: 660)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
#endif
