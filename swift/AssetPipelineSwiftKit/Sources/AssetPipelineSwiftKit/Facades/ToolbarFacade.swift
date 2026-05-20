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
        var content: AnyView = AnyView(
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    // Toolbar items derived from override arrays (data-
                    // driven). Custom-view children (childViews) are
                    // appended as additional ToolbarItem entries with
                    // the "primary" placement when present.
                    ForEach(0..<labels.count, id: \.self) { idx in
                        ToolbarItem(placement: placementFor(idx < placements.count ? placements[idx] : "primary")) {
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
                    }
                    ForEach(0..<childViews.count, id: \.self) { idx in
                        ToolbarItem(placement: .primaryAction) {
                            APSKHostedChild(view: childViews[idx])
                        }
                    }
                }
        )

        if let title = overrides.title, overrides.showsTitle?.boolValue != false {
            content = AnyView(content.navigationTitle(title))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
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
