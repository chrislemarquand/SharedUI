import Foundation

/// Observable state driving a `NoticeBarView`.
/// Mutate properties from the owning controller; the SwiftUI view reacts automatically.
@MainActor
@Observable
public final class NoticeBarState {
    public var message: String = ""
    public var primaryAction: NoticeBarAction?
    public var secondaryAction: NoticeBarAction?
    public var isVisible: Bool = false

    public init() {}
}

public struct NoticeBarAction {
    public let title: String
    public let handler: @MainActor () -> Void

    public init(title: String, handler: @MainActor @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}
