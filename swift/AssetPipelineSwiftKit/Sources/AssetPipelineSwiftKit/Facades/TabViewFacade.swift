// TabViewFacade — SwiftUI TabView bridge.
//
// One child per tab. The TabViewOverrides carries the parallel
// `tabLabels` + `tabIcons` arrays whose length matches the child count.
// Each tab is wrapped in a `.tabItem { Label(...) }`.
//
// `selectedTintColor` overrides the brand-cascade tint specifically for
// this TabView; SwiftUI applies it via `.tint()` scoped to the TabView.

import SwiftUI
import Foundation

@objc(APSKTabViewFacade)
public class TabViewFacade: NSObject {
    @objc public static func makeTabView(
        childViews: [APSKPlatformView],
        overrides: TabViewOverrides
    ) -> APSKPlatformView {
        let labels = overrides.tabLabels
        let icons = overrides.tabIcons
        let count = childViews.count
        let storage = IntStorage(initial: overrides.selectedIndex, token: 0)

        var content: AnyView = AnyView(
            TabView(selection: storage.binding) {
                ForEach(0..<count, id: \.self) { idx in
                    APSKHostedChild(view: childViews[idx])
                        .tabItem {
                            let label = idx < labels.count ? labels[idx] : ""
                            let icon = idx < icons.count ? icons[idx] : ""
                            if !icon.isEmpty && !label.isEmpty {
                                Label(label, systemImage: icon)
                            } else if !icon.isEmpty {
                                Image(systemName: icon)
                            } else {
                                Text(label)
                            }
                        }
                        .tag(idx)
                }
            }
        )

        if let tint = overrides.selectedTintColor {
            #if canImport(UIKit)
            content = AnyView(content.tint(Color(uiColor: tint)))
            #else
            content = AnyView(content.tint(Color(nsColor: tint)))
            #endif
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(TabHost(storage: storage, content: content))
    }
}

private struct TabHost<Content: View>: View {
    @ObservedObject var storage: IntStorage
    let content: Content
    var body: some View { content }
}
