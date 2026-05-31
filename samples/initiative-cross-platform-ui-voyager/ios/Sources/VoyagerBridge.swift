import UIKit
import Combine

/// Swift wrapper around the Crystal C-ABI bridge functions exposed by
/// `samples/initiative-cross-platform-ui-voyager/ios/bridge.cr` and
/// packaged into libvoyager.a.
///
/// Adds a Combine PassthroughSubject<String, Never> that fires whenever
/// the Crystal-side NavigationCoordinator's `on_change` callback fires.
/// The ContentView subscribes via `.onReceive` and updates its
/// `@State var slug`, which triggers SwiftUI to call
/// `VoyagerBridge.render(slug:)` again for the new route.
/// Why the coordinator re-published: a stack mutation (navigation) or a
/// same-route Rerender. The host tears down on navigation but reconciles
/// in place on a rerender (preserving text-field keyboard focus).
enum RouteChangeKind: Int32 {
    case navigation = 0
    case rerender = 1
}

struct RouteEvent {
    let slug: String
    let kind: RouteChangeKind
}

enum VoyagerBridge {
    private static var didInit = false

    /// Fired by Crystal whenever coord.push/pop/replace_root/republish
    /// runs, carrying the new slug AND why it changed.
    static let routeEvents = PassthroughSubject<RouteEvent, Never>()

    /// Legacy slug-only subject, kept for any subscriber that doesn't
    /// care about the change kind. ContentView uses `routeEvents`.
    static let routeChanged = PassthroughSubject<String, Never>()

    static func initialize() {
        guard !didInit else { return }
        voyager_init()
        voyager_register_route_changed_callback(VoyagerBridge.routeChangedThunk)
        didInit = true
    }

    /// C-callable trampoline. Crystal hands us a NUL-terminated UTF-8
    /// string pointer to a stable Crystal-managed buffer plus the change
    /// kind. We copy into a Swift String IMMEDIATELY (the pointer is only
    /// valid until the next Crystal call) and republish via Combine.
    private static let routeChangedThunk: @convention(c) (UnsafePointer<CChar>?, Int32) -> Void = { ptr, rawKind in
        guard let ptr = ptr else { return }
        let slug = String(cString: ptr)
        let kind = RouteChangeKind(rawValue: rawKind) ?? .navigation
        // Hop to the main queue — Combine subscribers in SwiftUI views
        // expect updates on the main run loop.
        DispatchQueue.main.async {
            VoyagerBridge.routeEvents.send(RouteEvent(slug: slug, kind: kind))
            VoyagerBridge.routeChanged.send(slug)
        }
    }

    /// Attempt an in-place reconcile for a same-route rerender. Returns
    /// true if Crystal applied the update in place (the host must NOT
    /// teardown), false to fall back to a full destructive render.
    static func reconcile(slug: String) -> Bool {
        initialize()
        return slug.withCString { voyager_reconcile($0) != 0 }
    }

    /// Render the given route slug and return the produced UIView.
    /// Crystal returns a retained UIView*; ownership transfers here via
    /// takeRetainedValue().
    static func render(slug: String) -> UIView? {
        initialize()
        return slug.withCString { ptr in
            guard let raw = voyager_render(ptr) else { return nil }
            let view = Unmanaged<UIView>.fromOpaque(raw).takeRetainedValue()
            view.accessibilityIdentifier = "voyager-root-\(slug)"
            view.isAccessibilityElement = false
            return view
        }
    }

    /// Read the coordinator's current slug — useful for unit tests +
    /// initial-state probes. Returns "voyager-sign-in" as a safe
    /// fallback if Crystal hasn't initialized yet.
    static func currentSlug() -> String {
        initialize()
        guard let ptr = voyager_current_slug() else { return "voyager-sign-in" }
        return String(cString: ptr)
    }
}
