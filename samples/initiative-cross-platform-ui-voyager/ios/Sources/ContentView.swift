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
        ScrollView(.vertical, showsIndicators: false) {
            VoyagerHost(slug: slug)
                .frame(maxWidth: .infinity, alignment: .top)
                .accessibilityIdentifier("voyager-root-host")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

/// A persistent container UIView that hosts the Crystal-rendered view
/// as its only subview. When `slug` changes, `updateUIView` rerenders
/// from Crystal and swaps the child. SwiftUI's UIViewRepresentable
/// contract is that `makeUIView` runs once per identity; `updateUIView`
/// runs on every state change. Because we return a stable container,
/// we have a place to swap children on slug changes.
struct VoyagerHost: UIViewRepresentable {
    let slug: String

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.accessibilityIdentifier = "voyager-host-container"
        installCrystalView(into: container, slug: slug)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        let currentSlugTag = (container.accessibilityValue ?? "")
        if currentSlugTag != slug {
            installCrystalView(into: container, slug: slug)
        }
    }

    private func installCrystalView(into container: UIView, slug: String) {
        for sub in container.subviews { sub.removeFromSuperview() }
        guard let fresh = VoyagerBridge.render(slug: slug) else {
            let fallback = UILabel()
            fallback.text = "render failed: \(slug)"
            fallback.accessibilityIdentifier = "voyager-root-fallback"
            fallback.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(fallback)
            NSLayoutConstraint.activate([
                fallback.topAnchor.constraint(equalTo: container.topAnchor),
                fallback.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                fallback.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                fallback.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            container.accessibilityValue = slug
            return
        }
        fresh.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fresh)
        NSLayoutConstraint.activate([
            fresh.topAnchor.constraint(equalTo: container.topAnchor),
            fresh.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            fresh.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            fresh.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.accessibilityValue = slug
        container.accessibilityIdentifier = "voyager-root-\(slug)"
    }
}
