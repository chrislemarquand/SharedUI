import AppKit
import SwiftUI

/// AppKit wrapper for `NoticeBarView`.
/// Add to your view hierarchy and update `state` to show/hide the bar.
/// The bar is 40pt tall when visible and 0pt when hidden.
public final class NoticeBar: NSView {
    public let state: NoticeBarState
    private let hostingView: NSHostingView<NoticeBarView>
    private var heightConstraint: NSLayoutConstraint!

    @MainActor
    public init(state: NoticeBarState = NoticeBarState()) {
        self.state = state
        self.hostingView = NSHostingView(rootView: NoticeBarView(state: state))
        super.init(frame: .zero)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Call after updating `state.isVisible` to animate the height change.
    @MainActor
    public func syncVisibility(animated: Bool = false) {
        let targetHeight: CGFloat = state.isVisible ? 40 : 0
        guard heightConstraint.constant != targetHeight else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.allowsImplicitAnimation = true
                heightConstraint.constant = targetHeight
                isHidden = !state.isVisible
                superview?.layoutSubtreeIfNeeded()
            }
        } else {
            heightConstraint.constant = targetHeight
            isHidden = !state.isVisible
        }
    }
}
