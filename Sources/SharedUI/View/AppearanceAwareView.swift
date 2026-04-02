import AppKit

@MainActor
public final class AppearanceAwareView: NSView {
    public var onEffectiveAppearanceChange: (() -> Void)?

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onEffectiveAppearanceChange?()
    }
}
