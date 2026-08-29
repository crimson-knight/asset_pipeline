// ColorPickerFacade — SwiftUI ColorPicker(...) bridge.

import SwiftUI
import Foundation

// watchOS: this facade is not in the watch catalog subset and/or uses UIKit-only
// APIs (UIView/UIControl/SwiftUI-on-watch-unavailable). Gated off watchOS for the
// initial one-facade green compile; watch-native re-enable is a Phase 12 follow-up.
#if !os(watchOS)
@objc(APSKColorPickerFacade)
public class ColorPickerFacade: NSObject {
    @objc public static func makeColorPicker(
        label: String,
        initialR: Double,
        initialG: Double,
        initialB: Double,
        initialA: Double,
        overrides: ColorPickerOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let initial = Color(.sRGB, red: initialR, green: initialG, blue: initialB, opacity: initialA)
        let storage = ColorStorage(initial: initial, token: actionToken)
        let supportsOpacity = overrides.supportsOpacity?.boolValue ?? false

        var content: AnyView = AnyView(
            ColorPicker(label, selection: storage.binding, supportsOpacity: supportsOpacity)
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(ColorHost(storage: storage, content: content))
    }
}

private struct ColorHost<Content: View>: View {
    @ObservedObject var storage: ColorStorage
    let content: Content
    var body: some View { content }
}
#endif
