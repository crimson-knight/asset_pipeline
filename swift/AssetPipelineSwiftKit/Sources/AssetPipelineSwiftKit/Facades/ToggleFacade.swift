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

        var content: AnyView = AnyView(Toggle(label, isOn: storage.binding))

        switch overrides.toggleStyle {
        case "button":   content = AnyView(content.toggleStyle(.button))
        case "switch":   content = AnyView(content.toggleStyle(.switch))
        #if canImport(AppKit)
        case "checkbox": content = AnyView(content.toggleStyle(.checkbox))
        #endif
        default: break
        }

        if let disabled = overrides.disabled, disabled.boolValue {
            content = AnyView(content.disabled(true))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(ToggleHost(storage: storage, content: content))
    }
}

private struct ToggleHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}
