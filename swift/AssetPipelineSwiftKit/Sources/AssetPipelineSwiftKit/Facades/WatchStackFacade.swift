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
        alignment: Int,
        overrides: ViewOverrides,
        rootFill: Int
    ) -> APSKPlatformView {
        let stack: AnyView
        if axis == 1 {
            let va: VerticalAlignment = alignment == 0 ? .top : (alignment == 2 ? .bottom : .center)
            stack = AnyView(
                HStack(alignment: va, spacing: spacing) {
                    ForEach(0..<childViews.count, id: \.self) { i in
                        childViews[i].content
                    }
                }
            )
        } else {
            let ha: HorizontalAlignment = alignment == 0 ? .leading : (alignment == 2 ? .trailing : .center)
            stack = AnyView(
                VStack(alignment: ha, spacing: spacing) {
                    ForEach(0..<childViews.count, id: \.self) { i in
                        childViews[i].content
                    }
                }
            )
        }
        // Apply the common view overrides (padding, frame min/max width + height,
        // background, opacity, border, shadow, accessibility) so VStack/HStack honor
        // the same adaptive layout props the imperative UIKit/AppKit stacks do. Without
        // this the watch dropped ALL container layout (root padding incl. safe-area
        // top, content-width pins) and shared screens couldn't reflow to the wrist.
        var content = CommonModifiers.apply(stack, overrides: overrides)
        // root_fill on watch: fill the WIDTH only and top-align. We deliberately do NOT
        // force maxHeight:.infinity here — watchOS hosts app content in a vertical
        // scroll context, and an infinite-height frame inside it is pathological (the
        // scroll view proposes unbounded height, so an inter-section Spacer + the fill
        // can't resolve and children collapse/overlap). Content taller than the watch
        // simply scrolls; content shorter is top-aligned by the leading frame alignment.
        if rootFill != 0 {
            content = AnyView(
                content.frame(maxWidth: .infinity, alignment: .top)
            )
        }
        return HostingHelpers.host(content, kind: axis == 1 ? "HStack" : "VStack")
    }
}
#endif
