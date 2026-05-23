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
        // `.id(slug)` forces SwiftUI to recreate the
        // UIViewRepresentable when the slug changes, which calls
        // `makeUIView` fresh each time. Without `.id(slug)`, SwiftUI
        // would only call `updateUIView` and reuse the existing UIView
        // wrapper — but VoyagerHost's `makeUIView` returns the Crystal
        // UIView (or a UIScrollView wrapping it) directly, so swapping
        // content requires a new representable identity.
        //
        // Phase 6.10 Rem 3 (Item 3) — VoyagerHost now wraps the Crystal
        // root in a UIKit `UIScrollView` (NOT a SwiftUI ScrollView) so
        // overflowing content scrolls gracefully on iPhone 17 portrait
        // while preserving the Item 2 AX-traversal win. UIScrollView is
        // an UIKit-native AX element; XCUITest walks it transparently
        // without `.contain` on a SwiftUI ScrollView (which collapsed
        // the subtree in Rem 2). When the Crystal-side screen
        // authoring uses its own UI::ScrollView (Layer B explicit
        // opt-in), VoyagerHost detects the already-scrollable root and
        // returns it as-is — no double scroll.
        //
        // Open: tap-to-on_tap interaction (Item 1) — addressed by the
        // HostingHelpers Path A VC parenting fix shipped in Rem 3.
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
        guard let crystalRoot = VoyagerBridge.render(slug: slug) else {
            let fallback = UILabel()
            fallback.text = "render failed: \(slug)"
            fallback.accessibilityIdentifier = "voyager-root-fallback"
            return fallback
        }
        crystalRoot.accessibilityIdentifier = "voyager-root-\(slug)"

        // Phase 6.10 Rem 3 (Item 3 Layer A — framework default):
        //
        // If the Crystal-side screen already wraps its content in a
        // UI::ScrollView (Layer B explicit override), the rendered root
        // IS already a UIScrollView — return it unwrapped to avoid
        // nested scrollviews.
        if crystalRoot is UIScrollView {
            return crystalRoot
        }

        // Otherwise wrap in a UIKit UIScrollView so any overflowing
        // content scrolls vertically. UIKit (NOT SwiftUI) UIScrollView
        // preserves the AX-tree traversal won in Rem 2 — XCUITest walks
        // through it transparently. Constraints pin the Crystal root's
        // edges to the scroll view's contentLayoutGuide and pin its
        // width to frameLayoutGuide so only the vertical axis scrolls
        // (mirrors the proven-working UIKit renderer's
        // uiscrollview_pin_content pattern at
        // `src/ui/renderers/uikit_renderer.cr#visit(ScrollView)`).
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.alwaysBounceHorizontal = false
        scroll.showsHorizontalScrollIndicator = false
        // Re-use the same AX identifier the bare-root path uses so
        // XCUITest selectors stay stable across the wrap / no-wrap
        // branches.
        scroll.accessibilityIdentifier = "voyager-root-\(slug)"

        crystalRoot.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(crystalRoot)
        // Phase 6.10 Rem 3 (Codex review 1, P2 #1): the width constraint
        // between the Crystal root and the scroll's frameLayoutGuide
        // must NOT be required priority. The Voyager screens emit a
        // required `min_w == max_w == 340.0` constraint on their root
        // VStack (UIKit renderer's `objc_constrain_*` helpers default
        // to priority 1000). A second required width constraint here
        // creates a conflict that Auto Layout resolves by breaking one
        // unpredictably. Use `.defaultHigh` (priority 750) so the
        // inner 340pt pin wins. The constraint's job is to prevent
        // horizontal overflow when the Crystal root has no explicit
        // width pin — high priority is sufficient because the scroll's
        // contentLayoutGuide leading/trailing anchors already define
        // the horizontal bounds.
        let widthHint = crystalRoot.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        widthHint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            crystalRoot.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            crystalRoot.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            crystalRoot.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            crystalRoot.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            widthHint,
        ])
        return scroll
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Stateless — slug changes recreate via `.id(slug)` on the
        // SwiftUI side, which discards this representable.
    }
}
