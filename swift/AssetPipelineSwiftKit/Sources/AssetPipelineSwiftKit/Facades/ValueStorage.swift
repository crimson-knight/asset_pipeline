// ValueStorage — shared @ObservedObject wrappers used by selection /
// form-control facades (Toggle, Slider, Stepper, Picker, etc.) to keep
// SwiftUI bindings alive across layout passes and propagate value
// changes back to Crystal through the CallbackBridge.

import SwiftUI
import Foundation

final class BoolStorage: ObservableObject {
    @Published var value: Bool
    let token: UInt64
    init(initial: Bool, token: UInt64) {
        self.value = initial
        self.token = token
    }
    var binding: Binding<Bool> {
        Binding(
            get: { self.value },
            set: { newValue in
                self.value = newValue
                CallbackBridge.fire(token: self.token, value: newValue ? 1.0 : 0.0)
            }
        )
    }
}

final class DoubleStorage: ObservableObject {
    @Published var value: Double
    let token: UInt64
    init(initial: Double, token: UInt64) {
        self.value = initial
        self.token = token
    }
    var binding: Binding<Double> {
        Binding(
            get: { self.value },
            set: { newValue in
                self.value = newValue
                CallbackBridge.fire(token: self.token, value: newValue)
            }
        )
    }
}

final class IntStorage: ObservableObject {
    @Published var value: Int
    let token: UInt64
    init(initial: Int, token: UInt64) {
        self.value = initial
        self.token = token
    }
    var binding: Binding<Int> {
        Binding(
            get: { self.value },
            set: { newValue in
                self.value = newValue
                CallbackBridge.fire(token: self.token, value: Double(newValue))
            }
        )
    }
}

final class DateStorage: ObservableObject {
    @Published var value: Date
    let token: UInt64
    init(initial: Date, token: UInt64) {
        self.value = initial
        self.token = token
    }
    var binding: Binding<Date> {
        Binding(
            get: { self.value },
            set: { newValue in
                self.value = newValue
                CallbackBridge.fire(token: self.token, value: newValue.timeIntervalSince1970)
            }
        )
    }
}

final class ColorStorage: ObservableObject {
    @Published var value: Color
    let token: UInt64
    init(initial: Color, token: UInt64) {
        self.value = initial
        self.token = token
    }
    var binding: Binding<Color> {
        Binding(
            get: { self.value },
            set: { newValue in
                self.value = newValue
                // Value channel carries 1.0 = "changed"; richer
                // colour-change dispatch is a future hook.
                CallbackBridge.fire(token: self.token, value: 1.0)
            }
        )
    }
}
