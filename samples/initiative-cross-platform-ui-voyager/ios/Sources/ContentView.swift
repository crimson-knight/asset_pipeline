import SwiftUI
import UIKit
import Combine

/// The Voyager root content view — owns a @State String tracking the
/// currently-visible route slug. When the Crystal-side coordinator
/// fires its route-changed callback (via VoyagerBridge.routeChanged
/// PassthroughSubject), this view's @State updates, which causes
/// SwiftUI to re-evaluate `body` and rebuild the hosted UIView via
/// VoyagerHost(slug:) — that calls VoyagerBridge.render(slug:) for
/// the new route.
///
/// This is the runtime-navigation substrate Phase 6.10 ships on iOS:
/// any Crystal-rendered button can call `coord.push(...)`, which fires
/// the on_change subscriber, which crosses into Swift via the C
/// trampoline, which re-renders the view tree.
struct ContentView: View {
    let initialSlug: String

    @State private var slug: String

    init(initialSlug: String) {
        self.initialSlug = initialSlug
        _slug = State(initialValue: initialSlug)
    }

    var body: some View {
        // Pattern mirrors the proven-working Cascade ContentView
        // (samples/initiative-cross-platform-ui-demo/ios/Sources/ContentView.swift).
        // Wrap the Crystal-produced UIView in a vertical ScrollView so any
        // screen taller than the iPhone portrait viewport remains reachable.
        // The Crystal-side screen authoring includes its own root padding so
        // inner gutters are honoured without extra Swift-side adornment.
        //
        // CRITICAL: `.id(slug)` forces SwiftUI to recreate the
        // UIViewRepresentable when the slug changes, which calls
        // `makeUIView` fresh each time. Without `.id(slug)`, SwiftUI
        // would only call `updateUIView` and reuse the existing UIView
        // wrapper — but VoyagerHost's `makeUIView` returns the Crystal
        // UIView DIRECTLY (no container wrapper), so swapping content
        // requires a new representable identity. This mirrors the
        // Cascade pattern which doesn't need swaps (one slug per
        // launch) but Voyager needs swaps on every coord.push/pop.
        // Phase 6.10 Rem 2 — VoyagerHost without outer SwiftUI
        // ScrollView, with `.accessibilityElement(children: .contain)`
        // on the host to surface the embedded Crystal UIKit subtree
        // through the SwiftUI -> UIKit representable boundary.
        //
        // Why no outer ScrollView:
        // Iter 2 tested both `.contain` on the inner host inside a
        // SwiftUI ScrollView wrapper AND on the outer ScrollView.
        // Both variants collapsed the AX subtree to an opaque
        // ScrollView with no discoverable children, blocking
        // `app.buttons["Sign in"]`. Without ScrollView, XCUI DOES
        // resolve `app.buttons["Sign in"]` and
        // `app.buttons["voyager-sign-in-submit"]` directly through
        // `.contain` on the host.
        //
        // Tradeoff: very-tall screens cannot scroll on iPhone 17
        // portrait. For Phase 6.10's 4-screen demo at iPhone 17
        // portrait (393x852pt), all screens fit naturally with the
        // 340pt content_width pin (verified via offscreen captures
        // at handoff/phase-06.10-remediation-2-evidence/). When
        // future screens require scrolling, use the Crystal-side
        // `UI::ScrollView` view type — its UIKit renderer maps to a
        // UIScrollView that preserves AX hierarchy.
        //
        // Open: tap-to-on_tap interaction (Item 1) — see
        // handoff/phase-06.10-remediation-2-codex-blocker.md.
        VoyagerHost(slug: slug)
            .id(slug)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("voyager-root-host")
            .accessibilityElement(children: .contain)
        .onReceive(VoyagerBridge.routeChanged) { newSlug in
            if newSlug != slug {
                slug = newSlug
            }
        }
        .onAppear {
            // Make sure VoyagerBridge.initialize runs so the route-changed
            // callback is registered BEFORE any tap handler inside the
            // Crystal view tree fires coord.push(...).
            VoyagerBridge.initialize()
        }
    }
}

/// Bridges a Crystal-produced UIView into the SwiftUI tree.
///
/// Mirrors Cascade's CascadeHost — return the Crystal UIStackView root
/// DIRECTLY so SwiftUI ScrollView reads its intrinsic content size
/// correctly. Wrapping in an extra UIView container with edge-pinned
/// constraints broke the intrinsic-size chain (the container had no
/// intrinsicContentSize of its own, so SwiftUI ScrollView gave it 0
/// height, which collapsed the inner UIStackView's arranged subviews).
///
/// Slug swaps are handled by `.id(slug)` on the SwiftUI side which
/// forces a fresh `makeUIView` call each time the route changes.
struct VoyagerHost: UIViewRepresentable {
    let slug: String

    func makeUIView(context: Context) -> UIView {
        if let view = VoyagerBridge.render(slug: slug) {
            view.accessibilityIdentifier = "voyager-root-\(slug)"
            return view
        }
        let fallback = UILabel()
        fallback.text = "render failed: \(slug)"
        fallback.accessibilityIdentifier = "voyager-root-fallback"
        return fallback
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Stateless — slug changes recreate via `.id(slug)` on the
        // SwiftUI side, which discards this representable.
    }
}
