// WatchStackFacade — watchOS-only declarative composition of VStack / HStack.
//
// On iOS/macOS, UI::VStack / UI::HStack compose imperatively in UIStackView /
// NSStackView (in the renderer, not via a facade). watchOS has no such imperative
// stack host — SwiftUI is the native layer — so the WatchKit renderer composes
// stacks DECLARATIVELY here: read each child boundary node's `.content` AnyView into
// a SwiftUI VStack/HStack and box the result as another APSKWatchHostView. See
// foundational-output-and-layout-model.md §"Principle 3" (the shared asset is the
// SwiftUI content of leaf facades; container composition is a separate watch impl).
#if os(watchOS)
import SwiftUI

@objc(APSKWatchStackFacade)
public class WatchStackFacade: NSObject {
    /// Compose child boundary nodes into a SwiftUI stack.
    /// - axis: 0 = vertical (VStack), 1 = horizontal (HStack).
    /// - alignment: 0 = leading/top, 1 = center, 2 = trailing/bottom.
    @objc public static func makeStack(
        childViews: [APSKWatchHostView],
        axis: Int,
        spacing: Double,
        alignment: Int
    ) -> APSKPlatformView {
        let content: AnyView
        if axis == 1 {
            let va: VerticalAlignment = alignment == 0 ? .top : (alignment == 2 ? .bottom : .center)
            content = AnyView(
                HStack(alignment: va, spacing: spacing) {
                    ForEach(0..<childViews.count, id: \.self) { i in
                        childViews[i].content
                    }
                }
            )
        } else {
            let ha: HorizontalAlignment = alignment == 0 ? .leading : (alignment == 2 ? .trailing : .center)
            content = AnyView(
                VStack(alignment: ha, spacing: spacing) {
                    ForEach(0..<childViews.count, id: \.self) { i in
                        childViews[i].content
                    }
                }
            )
        }
        return HostingHelpers.host(content, kind: axis == 1 ? "HStack" : "VStack")
    }
}
#endif
