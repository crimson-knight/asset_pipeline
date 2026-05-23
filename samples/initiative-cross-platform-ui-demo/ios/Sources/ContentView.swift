import SwiftUI
import UIKit

// Phase 6 Rem 4 fix #1: brand-teal tint cascade.
//
// The Crystal-side `InitiativeDemo.brand_tokens` returns a `Tokens` with
// brand_primary set to a deep teal (OKLCH 0.56, 0.13, 195 → sRGB
// approximately (0.012, 0.521, 0.521)). At the Crystal renderer level,
// `ensure_swiftkit_runtime!` installs the same colour via
// `apsk_runtime_set_brand_tint` so every Crystal-hosted SwiftUI Button
// inherits it through `HostingHelpers.host(_:)`'s `view.tint(...)`
// wrapper.
//
// This top-level `.tint(...)` on `ContentView` mirrors that brand tint
// at the host's outermost SwiftUI scope. Two reasons we apply it here in
// addition to the Crystal-side runtime call:
//
//   1. It covers any SwiftUI surface the host introduces outside the
//      embedded `CascadeHost` (a future "Settings" pane, a debug HUD,
//      etc.) so the entire app reads brand-teal even before the first
//      Crystal render call has set the runtime tint.
//   2. It documents the brand intent in the Swift source tree so the
//      iOS app reads as "brand-teal everywhere" without needing to
//      trace through the Crystal runtime to see why.
//
// The colour value matches `brand.cr#BRAND_PRIMARY_LIGHT`. Hardcoded
// rather than read from `AssetPipelineTokens.swift` because that dist
// file ships the DEFAULT amber palette — the demo's teal lives in the
// runtime tint, not the static dist.
private let cascadeBrandPrimary = Color(.sRGB,
                                        red: 0.012,
                                        green: 0.521,
                                        blue: 0.521,
                                        opacity: 1.0)

struct ContentView: View {
    let slug: String

    var body: some View {
        // Wrap the Crystal-produced UIView in a vertical ScrollView so any
        // screen taller than the iPhone portrait viewport remains reachable.
        // The Phase 6 Rem 2 sign-in baseline showed the Sign-in button +
        // Forgot-password link below the fold on iPhone 17 portrait
        // (1206 x 2622) because the root Crystal VStack vertical-centred
        // its content inside the available SwiftUI space. ScrollView pins
        // the content top-anchored, lets the user scroll if needed, and
        // costs nothing visually when the content already fits.
        ScrollView(.vertical, showsIndicators: false) {
            CascadeHost(slug: slug)
                .frame(maxWidth: .infinity, alignment: .top)
                .accessibilityIdentifier("cascade-root-host")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tint(cascadeBrandPrimary)
    }
}

/// Bridges a Crystal-produced UIView into the SwiftUI tree.
struct CascadeHost: UIViewRepresentable {
    let slug: String

    func makeUIView(context: Context) -> UIView {
        if let view = CascadeBridge.render(slug: slug) {
            return view
        }
        let fallback = UILabel()
        fallback.text = "render failed: \(slug)"
        fallback.accessibilityIdentifier = "cascade-root-fallback"
        return fallback
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
