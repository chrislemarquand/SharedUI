import SwiftUI

public struct InspectorScrollModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.container, edges: .top)
            .contentMargins(.top, InspectorMetrics.topScrollInset, for: .scrollContent)
    }
}

public extension View {
    func inspectorScrollSetup() -> some View {
        modifier(InspectorScrollModifier())
    }
}
