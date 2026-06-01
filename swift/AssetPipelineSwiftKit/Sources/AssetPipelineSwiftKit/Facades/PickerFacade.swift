// PickerFacade — SwiftUI Picker(...) with configurable picker style.

import SwiftUI
import Foundation

// watchOS: this facade is not in the watch catalog subset and/or uses UIKit-only
// APIs (UIView/UIControl/SwiftUI-on-watch-unavailable). Gated off watchOS for the
// initial one-facade green compile; watch-native re-enable is a Phase 12 follow-up.
#if !os(watchOS)
@objc(APSKPickerFacade)
public class PickerFacade: NSObject {
    @objc public static func makePicker(
        label: String,
        options: [String],
        selectedIndex: Int,
        overrides: PickerOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = IntStorage(initial: selectedIndex, token: actionToken)

        var content: AnyView = AnyView(
            Picker(label, selection: storage.binding) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                    Text(opt).tag(idx)
                }
            }
        )

        switch overrides.pickerStyle {
        case "menu":
            content = AnyView(content.pickerStyle(.menu))
        case "wheel":
            #if canImport(UIKit)
            content = AnyView(content.pickerStyle(.wheel))
            #endif
        case "segmented":
            content = AnyView(content.pickerStyle(.segmented))
        case "inline":
            content = AnyView(content.pickerStyle(.inline))
        case "navigationlink":
            #if canImport(UIKit)
            content = AnyView(content.pickerStyle(.navigationLink))
            #endif
        default: break
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(IntHost(storage: storage, content: content))
    }
}
#endif
