// ValueStorage — shared @ObservedObject wrappers used by selection /
// form-control facades (Toggle, Slider, Stepper, Picker, etc.) to keep
// SwiftUI bindings alive across layout passes and propagate value
// changes back to Crystal through the CallbackBridge.

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreGraphics

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
                // Colour value channel: encode the NEW pick as "r,g,b,a"
                // (sRGB, 0...1, POSIX '.' via String(format:)) and fire the
                // STRING trampoline — mirrors the TextField string channel.
                // The Crystal renderer registers a register_string callback
                // that parses this into a UI::Color. The old
                // fire(token, 1.0) dropped the pick entirely.
                let (r, g, b, a) = ColorStorage.rgbaComponents(newValue)
                let encoded = String(format: "%.6f,%.6f,%.6f,%.6f", r, g, b, a)
                CallbackBridge.fireString(token: self.token, value: encoded)
            }
        )
    }

    /// Extract display-sRGB RGBA components (0...1) from a SwiftUI Color,
    /// resilient to wide-gamut (Display P3) picks via CGColor sRGB
    /// conversion (clamping raw extended/P3 channels would mis-map them).
    static func rgbaComponents(_ color: Color) -> (Double, Double, Double, Double) {
        if let cg = color.cgColor,
           let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
           let converted = cg.converted(to: srgbSpace, intent: .defaultIntent, options: nil),
           let comps = converted.components, comps.count >= 3 {
            let a = comps.count >= 4 ? comps[3] : 1.0
            return (Double(comps[0]).clampedUnit, Double(comps[1]).clampedUnit,
                    Double(comps[2]).clampedUnit, Double(a).clampedUnit)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        #if canImport(UIKit)
        if UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r).clampedUnit, Double(g).clampedUnit,
                    Double(b).clampedUnit, Double(a).clampedUnit)
        }
        #elseif canImport(AppKit)
        if let srgb = NSColor(color).usingColorSpace(.sRGB) {
            srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r).clampedUnit, Double(g).clampedUnit,
                    Double(b).clampedUnit, Double(a).clampedUnit)
        }
        #endif
        return (0.0, 0.0, 0.0, 1.0)
    }
}

private extension Double {
    var clampedUnit: Double { Swift.min(1.0, Swift.max(0.0, self)) }
}
