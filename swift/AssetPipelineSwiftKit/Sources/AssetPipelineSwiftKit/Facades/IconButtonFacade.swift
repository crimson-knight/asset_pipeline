// IconButtonFacade — SwiftUI Button(action:) with an SF Symbol label.

import SwiftUI
import Foundation

@objc(APSKIconButtonFacade)
public class IconButtonFacade: NSObject {
    @objc public static func makeIconButton(
        icon: String,
        overrides: IconButtonOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let action: () -> Void = {
            CallbackBridge.fire(token: actionToken, value: 0)
        }
        let size = CGFloat(overrides.iconSize?.doubleValue ?? 24.0)

        let label = overrides.label
        let symbol = Image(systemName: icon)
            .font(.system(size: size))

        var content: AnyView
        if let lbl = label, !lbl.isEmpty {
            content = AnyView(Button(action: action) {
                Label(lbl, systemImage: icon)
            })
        } else {
            // Icon-only button. Give the label an explicit, HIG-minimum (44pt)
            // tappable frame + a content shape. Without an explicit size, an
            // icon-only SwiftUI Button can report an ambiguous/zero intrinsic
            // content size, which crashes the iOS UIHostingController constraint
            // solver (hosted with sizingOptions [.intrinsicContentSize]); macOS
            // NSHostingView tolerates it. The explicit frame fixes the iOS crash
            // and is also the correct minimum hit target.
            let tap = max(size + 16, 44)
            content = AnyView(Button(action: action) {
                symbol
                    .frame(minWidth: tap, minHeight: tap)
                    .contentShape(Rectangle())
            })
        }

        if let disabled = overrides.disabled, disabled.boolValue {
            content = AnyView(content.disabled(true))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }
}
