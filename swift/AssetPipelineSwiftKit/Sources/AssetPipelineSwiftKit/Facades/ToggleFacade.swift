// ToggleFacade — SwiftUI Toggle(isOn:) bridge.
//
// Phase 3 Remediation 4: `makeReactiveToggle` writes the underlying
// `BoolStorage` pointer through `outState` so Crystal can mutate
// `storage.value` later via `apsk_toggle_set_value` (programmatic isOn).

import SwiftUI
import Foundation

@objc(APSKToggleFacade)
public class ToggleFacade: NSObject {
    @objc public static func makeToggle(
        label: String,
        isOn: Bool,
        overrides: ToggleOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        return makeReactiveToggle(
            label: label, isOn: isOn,
            overrides: overrides, actionToken: actionToken, outState: nil
        )
    }

    @objc public static func makeReactiveToggle(
        label: String,
        isOn: Bool,
        overrides: ToggleOverrides,
        actionToken: UInt64,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        let storage = BoolStorage(initial: isOn, token: actionToken)

        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(storage).toOpaque()
        }

        return HostingHelpers.host(
            ToggleHost(
                label: label,
                storage: storage,
                overrides: overrides
            )
        )
    }
}

// The Toggle is constructed INSIDE the View `body` so the binding it
// reads (`$storage.value`) is rebuilt every time SwiftUI re-evaluates the
// host. Building the Toggle outside the View (the prior shape) made the
// Binding go through a closure-built `Binding(get:set:)` whose
// accessibility-activate hook iOS 26 does not pick up when the
// UIHostingController is mounted via UIViewRepresentable — BX3's
// XCUITest tap reached the AX Switch element but never flipped isOn.
private struct ToggleHost: View {
    let label: String
    @ObservedObject var storage: BoolStorage
    let overrides: ToggleOverrides

    var body: some View {
        // $storage.value is the Published projected value — the canonical
        // binding SwiftUI uses for AX activation. We still fire the
        // Crystal-side callback by observing changes via .onChange below
        // so the BoolStorage closure-binding side-effect (CallbackBridge
        // fire) keeps running on every flip.
        var content: AnyView = AnyView(
            Toggle(label, isOn: $storage.value)
                .onChange(of: storage.value) { newValue in
                    // Suppress when the change was driven by a
                    // Crystal-side programmatic mutation (set via
                    // `apsk_toggle_set_value` -> `setProgrammatically`).
                    // Without this guard the on_change handler would fire
                    // a callback for every Crystal-initiated state push.
                    if storage.suppressNextFire {
                        storage.suppressNextFire = false
                        return
                    }
                    CallbackBridge.fire(
                        token: storage.token,
                        value: newValue ? 1.0 : 0.0
                    )
                }
        )

        switch overrides.toggleStyle {
        case "button":   content = AnyView(content.toggleStyle(.button))
        case "switch":   content = AnyView(content.toggleStyle(.switch))
        #if canImport(AppKit)
        case "checkbox": content = AnyView(content.toggleStyle(.checkbox))
        #endif
        default:
            // Default to .switch on iOS so the AX trait is unambiguously
            // "switch" (matches XCUITest `.switches[...]` lookup) and the
            // tap target is the UISwitch shell.
            #if canImport(UIKit)
            content = AnyView(content.toggleStyle(.switch))
            #endif
        }

        if let disabled = overrides.disabled, disabled.boolValue {
            content = AnyView(content.disabled(true))
        }

        return CommonModifiers.apply(content, overrides: overrides)
    }
}
