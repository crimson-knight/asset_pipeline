// ValueStorage — shared @ObservedObject wrappers used by selection /
// form-control facades (Toggle, Slider, Stepper, Picker, etc.) to keep
// SwiftUI bindings alive across layout passes and propagate value
// changes back to Crystal through the CallbackBridge.

import SwiftUI
import Foundation

final class BoolStorage: ObservableObject {
    @Published var value: Bool
    let token: UInt64
    /// When true, `setProgrammatically(_:)` is updating `value` from a
    /// Crystal-side `apsk_toggle_set_value` call. The facade's `.onChange`
    /// callback uses this flag to suppress an outbound CallbackBridge.fire
    /// — programmatic mutations are NOT user interactions and must not
    /// re-fire the Crystal `on_change` handler.
    var suppressNextFire: Bool = false
    /// Phase 12.A — Interaction-contracts marker tag. When set, BoolStorage
    /// emits [APIC:<markerWidget>:<event>] markers via InteractionContracts
    /// at present / dismiss transitions. Presentation widgets (Sheet,
    /// Popover, ConfirmationDialog, Alert, FullScreenCover, Inspector) set
    /// this; non-presentation BoolStorage users (Toggle, etc.) leave it nil.
    var markerWidget: String? = nil
    var viewID: String? = nil
    init(initial: Bool, token: UInt64) {
        self.value = initial
        self.token = token
        // Emit a "present" marker if the dialog/sheet/popover begins
        // already presented — this matches Crystal pushing isPresented=true
        // into the renderer at construction time.
        if initial, let widget = markerWidget {
            InteractionContracts.emit(
                widget: widget,
                event: "present",
                viewID: viewID,
                kv: ["initial": "true"]
            )
        }
    }
    /// Crystal-driven programmatic mutation entry point. Sets `value`
    /// while flagging the change so the facade's `.onChange` observer
    /// skips its callback fire.
    func setProgrammatically(_ newValue: Bool) {
        suppressNextFire = true
        let previousValue = value
        value = newValue
        if let widget = markerWidget {
            if !previousValue && newValue {
                InteractionContracts.emit(
                    widget: widget,
                    event: "present",
                    viewID: viewID,
                    kv: ["trigger": "crystal-push"]
                )
            } else if previousValue && !newValue {
                InteractionContracts.emit(
                    widget: widget,
                    event: "platform-dismissed",
                    viewID: viewID,
                    kv: ["trigger": "crystal-push"]
                )
            }
        }
    }
    var binding: Binding<Bool> {
        Binding(
            get: { self.value },
            set: { newValue in
                let previousValue = self.value
                // Phase 12.A — emit `binding-write-false` always on the
                // true→false transition (proves SwiftUI wrote false). Emit
                // `dismiss-token-fire` only when token != 0 (proves the
                // Crystal dismiss handler path fired). Codex Phase 12.A
                // CONCERN 5 fix: ConfirmationDialog binds token=0 (its
                // dismissal flows through confirmToken/cancelToken, not the
                // BoolStorage token), so the prior unconditional
                // `dismiss-token-fire` was misleading.
                if let widget = self.markerWidget, previousValue && !newValue {
                    InteractionContracts.emit(
                        widget: widget,
                        event: "binding-write-false",
                        viewID: self.viewID,
                        kv: [:]
                    )
                    if self.token != 0 {
                        InteractionContracts.emit(
                            widget: widget,
                            event: "dismiss-token-fire",
                            viewID: self.viewID,
                            kv: ["token": String(self.token)]
                        )
                    }
                }
                self.value = newValue
                CallbackBridge.fire(token: self.token, value: newValue ? 1.0 : 0.0)
                if let widget = self.markerWidget, previousValue && !newValue {
                    InteractionContracts.emit(
                        widget: widget,
                        event: "platform-dismissed",
                        viewID: self.viewID,
                        kv: [:]
                    )
                }
            }
        )
    }
}

final class DoubleStorage: ObservableObject {
    @Published var value: Double
    let token: UInt64
    /// See BoolStorage.suppressNextFire — same semantics for sliders /
    /// other Double-bound controls.
    var suppressNextFire: Bool = false
    init(initial: Double, token: UInt64) {
        self.value = initial
        self.token = token
    }
    func setProgrammatically(_ newValue: Double) {
        suppressNextFire = true
        value = newValue
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
