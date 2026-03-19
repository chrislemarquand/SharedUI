import SwiftUI

public struct InspectorFieldRow<Label: View, Value: View>: View {
    let label: Label
    let value: Value

    public init(@ViewBuilder label: () -> Label, @ViewBuilder value: () -> Value) {
        self.label = label()
        self.value = value()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            label
            value
        }
    }
}
