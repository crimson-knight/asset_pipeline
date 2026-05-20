// PopoverFacade — SwiftUI .popover(isPresented:) bridge.
//
// macOS has rich popover support; iOS has limited popover behavior
// (most popovers degrade to sheets at compact size classes). SwiftUI
// handles this transparently — the `.popover` modifier defers to the
// runtime to pick the right presentation.

import SwiftUI
import Foundation

@objc(APSKPopoverFacade)
public class PopoverFacade: NSObject {
    @objc public static func makePopover(
        childViews: [APSKPlatformView],
        overrides: PopoverOverrides,
        dismissToken: UInt64
    ) -> APSKPlatformView {
        let isPresented = overrides.isPresented?.boolValue ?? false
        let storage = BoolStorage(initial: isPresented, token: dismissToken)

        let body: AnyView
        if let first = childViews.first {
            body = AnyView(APSKHostedChild(view: first))
        } else {
            body = AnyView(EmptyView())
        }

        let arrow: Edge
        switch overrides.arrowEdge {
        case "top":      arrow = .top
        case "bottom":   arrow = .bottom
        case "leading":  arrow = .leading
        case "trailing": arrow = .trailing
        default:         arrow = .bottom
        }

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .popover(isPresented: storage.binding, arrowEdge: arrow) {
                    Group {
                        body
                    }
                    .frame(
                        minWidth: overrides.preferredWidth.map { CGFloat($0.doubleValue) },
                        minHeight: overrides.preferredHeight.map { CGFloat($0.doubleValue) }
                    )
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(PopoverHost(storage: storage, content: content))
    }
}

private struct PopoverHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}
