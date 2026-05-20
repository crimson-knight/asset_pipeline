// ToggleFacade — SwiftUI Toggle(isOn:) bridge.

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
        let storage = BoolStorage(initial: isOn, token: actionToken)
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
