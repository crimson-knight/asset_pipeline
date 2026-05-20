// LinkButtonFacade — SwiftUI Link(_:destination:) bridge.
//
// The system handles tap routing, focus, hover, and accent colour
// (which inherits the brand tint cascade). On a non-URL value we fall
// back to a regular Button that fires the action token so Crystal-side
// custom routing still works.

import SwiftUI
import Foundation

@objc(APSKLinkButtonFacade)
public class LinkButtonFacade: NSObject {
    @objc public static func makeLinkButton(
        label: String,
        url: String,
        overrides: LinkButtonOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        var content: AnyView
        if let parsed = URL(string: url), !url.isEmpty {
            content = AnyView(Link(label, destination: parsed))
        } else {
            content = AnyView(Button(label) {
                CallbackBridge.fire(token: actionToken, value: 0)
            })
        }
        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }
}
