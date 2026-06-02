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

// watchOS: ENABLED (Phase D Bucket-2 P1 port, 2026-06-02). `TabView(selection:)`,
// `.tabItem`, `.tag`, and `.tint` are valid on watchOS (vertical-page paging is the
// watch idiom). The tab-bar chrome block (`.toolbarBackground` is
// `@available(watchOS, unavailable)`, `.glassEffect()` uncertain on watch) is gated
// for non-watch — the watch presents TabView with its native page chrome. See
// watch-facade-bucket-audit.md.
@objc(APSKTabViewFacade)
public class TabViewFacade: NSObject {
    @objc public static func makeTabView(
        childViews: [APSKPlatformView],
        overrides: TabViewOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let labels = overrides.tabLabels
        let icons = overrides.tabIcons
        let count = childViews.count
        // Thread the Crystal callback token so a tab change fires
        // CallbackBridge.fire(token, Double(index)) — previously hardcoded
        // to 0, so the on_change handler never received the new index.
        let storage = IntStorage(initial: overrides.selectedIndex, token: actionToken)

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

        // Phase 5 v2 — always apply `.toolbarBackground(.bar, for: .automatic)`
        // for the tab-bar chrome per brief.yml I-1: "SystemResolved does NOT
        // suppress TabView/Toolbar `.toolbarBackground(.bar, for: .automatic)`
        // — that's the canonical SwiftUI bar chrome, separate from the
        // setMaterial: surface." Per architecture doc lines 88-89, .tabBar
        // placement is iOS-only; .automatic is cross-platform-safe.
        //
        // When the caller overrides materialSemantic to a non-system role,
        // the resolved Material replaces .bar. Otherwise .bar is the default.
        //
        // Phase 5 v2 Rem1 — iOS 26+ / macOS 26+ Liquid Glass path: per
        // architecture doc lines 117 + 119-120, the 26+ SDKs swap the pre-26
        // per-widget modifier for `.glassEffect()`. `.glassEffect()` is
        // advisory only on this path — the system resolves material strength
        // regardless of the AppleSemantic + intensity inputs. This mirrors
        // the GlassBackgroundFacade.swift:64-70 reference pattern.
        // watchOS: `.toolbarBackground` is unavailable and `.glassEffect()` is not
        // a watch presentation idiom; the watch shows TabView with its native page
        // chrome, so the bar-background block is skipped entirely on watch.
        #if !os(watchOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            content = AnyView(content.glassEffect())
        } else if #available(iOS 16.0, macOS 13.0, *) {
            let materialKey: String = overrides.materialSemantic ?? "system_resolved"
            let mat: Material = MaterialSemanticResolver.material(for: materialKey) ?? .bar
            content = AnyView(content.toolbarBackground(mat, for: .automatic))
        }
        #endif

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(TabHost(storage: storage, content: content))
    }
}

private struct TabHost<Content: View>: View {
    @ObservedObject var storage: IntStorage
    let content: Content
    var body: some View { content }
}
