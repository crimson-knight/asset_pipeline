import SwiftUI

extension View {
    /// Uses the current value-change callback while retaining supported older OSes.
    @ViewBuilder
    func observingValueChanges<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}
