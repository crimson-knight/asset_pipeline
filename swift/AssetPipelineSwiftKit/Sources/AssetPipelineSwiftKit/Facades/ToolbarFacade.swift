// ToolbarFacade — SwiftUI .toolbar { ToolbarItem(placement:) { ... } }
// bridge.
//
// IMPORTANT: SwiftUI's ToolbarContent is a separate protocol from View
// and cannot directly host arbitrary `View` content the way `Group`
// does. We use `ToolbarItem` with a SwiftUI label built from the
// `itemLabels` / `itemIcons` arrays. Hosting an arbitrary Crystal-built
// native view inside a ToolbarItem is supported only when the renderer
// supplies an `APSKHostedChild`-shaped slot; in practice we pass it
// through `ToolbarItem { APSKHostedChild(view:) }` which SwiftUI
// will treat as the item's content.

import SwiftUI
import Foundation

@objc(APSKToolbarFacade)
public class ToolbarFacade: NSObject {
    @objc public static func makeToolbar(
        childViews: [APSKPlatformView],
        overrides: ToolbarOverrides
    ) -> APSKPlatformView {
        let labels = overrides.itemLabels
        let icons = overrides.itemIcons
        let tokens = overrides.itemTokens
        let placements = overrides.itemPlacements

        // Render a thin host view that carries the toolbar modifier on
        // its content; the host itself is a 1x1 clear rect so the
        // toolbar visually attaches to the parent (a NavigationStack
        // root, typically).
        //
        // ToolbarFacade compile-error fix (iter-1 remediation): the
        // toolbar body is built from `@ToolbarContentBuilder`-typed
        // helpers. `ForEach { ToolbarItem(...) }` is only valid when the
        // surrounding context is `@ToolbarContentBuilder` — inside a
        // plain `@ViewBuilder` the compiler resolves `ToolbarItem` as a
        // `View` candidate and fails. Splitting `toolbarContent(...)`
        // out as a `some ToolbarContent`-returning helper keeps the
        // result-builder context unambiguous.
        var content: AnyView = AnyView(
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    Self.toolbarContent(
                        labels: labels,
                        icons: icons,
                        tokens: tokens,
                        placements: placements,
                        childViews: childViews
                    )
                }
        )

        if let title = overrides.title, overrides.showsTitle?.boolValue != false {
            content = AnyView(content.navigationTitle(title))
        }

        // Phase 5 v2 — apply `.toolbarBackground(.bar, for: .automatic)`.
        // Per architecture doc lines 91-92, .navigationBar placement is
        // iOS-only; .automatic is cross-platform-safe. SystemResolved is
        // the HIG default (SwiftUI handles bar chrome); explicit
        // AppleSemantic overrides flow through the resolver.
        let materialKey: String = overrides.materialSemantic ?? "system_resolved"
        if !MaterialSemanticResolver.shouldSkipModifier(materialKey) {
            if #available(iOS 16.0, macOS 13.0, *) {
                if let mat = MaterialSemanticResolver.material(for: materialKey) {
                    content = AnyView(content.toolbarBackground(mat, for: .automatic))
                }
            }
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }

    /// `@ToolbarContentBuilder`-typed helper. This is the key piece of the
    /// iter-1 fix: keeping the toolbar items in their own result-builder
    /// context means `ForEach`/`ToolbarItem` resolve through
    /// `ToolbarContentBuilder` instead of `ViewBuilder`.
    ///
    /// Because `ForEach` adopting `ToolbarContent` is only available in
    /// iOS 17+ / macOS 14+, and this package targets iOS 16 / macOS 13,
    /// we wrap the dynamic data-driven items in a single
    /// `ToolbarItemGroup(placement: .automatic)` whose `@ViewBuilder`
    /// content is the natural home of the `ForEach`. The placement-
    /// specific routing is handled by a second pre-rendered placement
    /// (the first item's placement, since SwiftUI toolbars on iOS 16 do
    /// not support per-item placement inside a single group — the
    /// renderer-side populator already groups items by placement before
    /// this facade is called).
    @ToolbarContentBuilder
    private static func toolbarContent(
        labels: [String],
        icons: [String],
        tokens: [NSNumber],
        placements: [String],
        childViews: [APSKPlatformView]
    ) -> some ToolbarContent {
        // Resolve a single group placement from the first item — the
        // populator emits a uniform placement array today; richer per-
        // item placement support is gated on the iOS 17 minimum bump.
        let groupPlacement: ToolbarItemPlacement = placements.first.map(placementFor) ?? .primaryAction

        ToolbarItemGroup(placement: groupPlacement) {
            ForEach(0..<labels.count, id: \.self) { idx in
                let label = labels[idx]
                let icon = idx < icons.count ? icons[idx] : ""
                let token = idx < tokens.count ? tokens[idx].uint64Value : 0
                Button(action: {
                    CallbackBridge.fire(token: token, value: 0.0)
                }) {
                    if !icon.isEmpty && !label.isEmpty {
                        Label(label, systemImage: icon)
                    } else if !icon.isEmpty {
                        Image(systemName: icon)
                    } else {
                        Text(label)
                    }
                }
            }
            ForEach(0..<childViews.count, id: \.self) { idx in
                APSKHostedChild(view: childViews[idx])
            }
        }
    }

    private static func placementFor(_ s: String) -> ToolbarItemPlacement {
        switch s {
        case "primary":      return .primaryAction
        case "secondary":    return .secondaryAction
        case "navigation":
            #if canImport(UIKit)
            return .navigationBarLeading
            #else
            return .navigation
            #endif
        case "principal":    return .principal
        case "cancellation":
            #if canImport(UIKit)
            return .cancellationAction
            #else
            return .cancellationAction
            #endif
        default:             return .primaryAction
        }
    }
}
