// HostingHelpers — platform-conditional aliases and the single `host(_:)`
// helper every facade routes through to wrap a SwiftUI view in a hosting
// surface and return it as a raw platform pointer. UIKit embeds its lifecycle
// observer in the SwiftUI content via UIViewRepresentable and returns the
// controller-owned root unchanged; AppKit returns NSHostingView directly.
//
// Architectural decision (§5.6): one `UIHostingController` per widget facade.
// This matches the "Crystal builds a widget, hands the pointer to a parent"
// model that every existing visit method assumes. Performance optimization
// of nested hosting controllers is explicitly out of scope for Phase 3.
//
// Known SwiftUI quirk addressed here (§5.6): inside `Form` / `List`, a
// `UIViewRepresentable` child can collapse to zero intrinsic size on the
// first layout pass. `host(_:)` wraps every view in
// `.frame(minWidth: 1, minHeight: 1)` so the intrinsic-size invariant
// stays positive on the first pass; the real content size propagates
// normally on the next pass and the 1pt floor is never visible.
//
// `APSKPlatformView` is declared in `Overrides/ViewOverrides.swift` and
// MUST NOT be redeclared here — Swift rejects the duplicate
// `public typealias` (see implementation.md §5.5 + line 701).

import SwiftUI

// watchOS gating: `canImport(UIKit)` is TRUE on watchOS but UIView/UIHostingController
// are `API_UNAVAILABLE(watchos)`, so `os(watchOS)` MUST be matched first. watchOS
// has no hosting controller — SwiftUI is the native layer.
#if os(watchOS)
// No APSKHostingController on watchOS; host(_:) boxes the SwiftUI content.
#elseif canImport(UIKit)
import UIKit
// APSKPlatformView is declared in ViewOverrides.swift; do not redeclare.
public typealias APSKHostingController = UIHostingController
#elseif canImport(AppKit)
import AppKit
// APSKPlatformView is declared in ViewOverrides.swift; do not redeclare.
public typealias APSKHostingController = NSHostingController

// On AppKit we prefer NSHostingView directly over NSHostingController:
// the view *is* the hosting surface, reports the SwiftUI root's
// intrinsic content size to NSStackView without any extra sizing-options
// dance, and produces a stable +1-retain NSView pointer the Crystal
// renderer can hand to `ObjC.owned(...)`. NSHostingController exists
// for cases where the SwiftUI root needs to participate in a view
// controller hierarchy (e.g. an NSWindow's contentViewController); a
// Crystal-driven AppKit renderer never needs that layer.
#endif

/// Anchor key for the associated hosting-controller object. The hosting
/// controller must live as long as the returned `.view` does; ObjC
/// associations are the cleanest way to attach that lifetime without
/// modifying the platform view itself.
private var kHostingControllerKey: UInt8 = 0

#if canImport(UIKit) && !os(watchOS)
/// Weak indirection lets the SwiftUI content capture its hosting controller
/// before the controller itself has been initialized.
///
/// Rejected approaches (per Codex review 1 + 2):
/// - `deinit` cleanup: the parent VC's `children` array retains its
///   children until `removeFromParent()` runs, so ARC cannot reach
///   `deinit` while the controller is still parented. `.id(slug)`
///   reroute paths therefore leaked stale child controllers.
/// - `view.window` KVO: empirically did not fire on iOS 26 simulator
///   under the current SwiftUI hosting model.
/// - Replacing the controller's `.view` with our own subclass via
///   `loadView()`: breaks SwiftUI's render surface, the SwiftUI
///   content stops drawing entirely.
/// - `viewWillDisappear`-only detach: doesn't fire on `.id(slug)`
///   discard — SwiftUI never asks the off-screen controller's view
///   to disappear normally.
///
/// Accepted approach: insert the lifecycle observer through the SwiftUI tree's
/// `UIViewRepresentable` boundary. This is the supported way for application
/// code to participate below `UIHostingController.view` on iOS 26, keeps the
/// returned root view and its ownership contract unchanged, and still gives us
/// reliable window-add/window-remove callbacks.
@available(iOS 13.0, tvOS 13.0, *)
final class APSKHostingControllerBox {
    weak var controller: APSKAttachingHostingController?
}

@available(iOS 13.0, tvOS 13.0, *)
final class APSKHostingWindowObserverView: UIView {
    weak var hostingController: APSKAttachingHostingController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            hostingController?.attachIfNeeded()
        } else {
            hostingController?.detachIfNeeded()
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct APSKHostingWindowObserver: UIViewRepresentable {
    let box: APSKHostingControllerBox

    func makeUIView(context: Context) -> APSKHostingWindowObserverView {
        let observer = APSKHostingWindowObserverView(frame: .zero)
        observer.hostingController = box.controller
        return observer
    }

    func updateUIView(_ observer: APSKHostingWindowObserverView, context: Context) {
        observer.hostingController = box.controller
    }
}

/// UIHostingController subclass that uses the representable observer above to
/// mirror its window membership into UIKit child-controller containment.
@available(iOS 13.0, tvOS 13.0, *)
final class APSKAttachingHostingController: UIHostingController<AnyView> {

    fileprivate func attachIfNeeded() {
        guard parent == nil, view.window != nil else { return }
        if let parent = nextParentViewController() {
            parent.addChild(self)
            didMove(toParent: parent)
        }
    }

    fileprivate func detachIfNeeded() {
        guard parent != nil else { return }
        willMove(toParent: nil)
        removeFromParent()
    }

    private func nextParentViewController() -> UIViewController? {
        var responder: UIResponder? = view.next
        while let r = responder {
            if let vc = r as? UIViewController, vc !== self {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

#endif

enum HostingHelpers {
    /// Wrap `view` in a hosting controller, retain the controller for the
    /// lifetime of its `.view`, and return the platform view.
    ///
    /// Crystal's `NativeHandle` takes ownership of the returned view pointer
    /// (+1 retain). The hosting controller is associated with the view via
    /// `objc_setAssociatedObject` so it lives as long as the view does.
    ///
    /// The `.frame(minWidth: 1, minHeight: 1)` defensive sizing is required
    /// for the SwiftUI Form/List re-measure quirk documented in §5.6.
    ///
    /// On UIKit a zero-size representable observer inside the SwiftUI content
    /// performs standards-compliant parent view-controller attachment when the
    /// root enters a window. AppKit is unaffected — NSHostingView reports
    /// actions independently of NSViewController containment.
    static func host<V: View>(_ view: V, kind: String = "") -> APSKPlatformView {
        // Apply the brand tint last so it cascades into every child view
        // SwiftUI considers part of this hosted root. Hosted roots are
        // isolated tint scopes — there is no propagation across
        // `UIHostingController` / `NSHostingController` boundaries — so
        // each facade re-applies the currently installed brand tint.
        // When no tint has been installed (`APSKRuntime.brandTint == nil`)
        // SwiftUI's system accent colour shows through unchanged.
        let tinted: AnyView
        if let tint = APSKRuntime.brandTint {
            tinted = AnyView(view.tint(tint))
        } else {
            tinted = AnyView(view)
        }
        let sized = AnyView(tinted.frame(minWidth: 1, minHeight: 1))

        let platformView: APSKPlatformView
        var lifetimeOwner: AnyObject? = nil
        #if os(watchOS)
        // watchOS: no UIView host — SwiftUI is native, so box the (tinted, sized)
        // SwiftUI content. The box is self-owning; no hosting controller to retain.
        // `kind` (empty unless the caller passes it) is the boundary node's stable
        // identity for the reconciler; the Crystal renderer may also stamp it later.
        platformView = APSKWatchHostView(content: sized, kind: kind)
        #elseif canImport(UIKit)
        // UIHostingController with its lifecycle observer embedded through
        // UIViewRepresentable keeps the controller-owned root unchanged.
        // `sizingOptions` is set BEFORE first access to `.view` so the
        // hosted UIView reports the SwiftUI intrinsic size on the first
        // layout pass; the prior order produced a CGSizeZero report and
        // collapsed the button to invisible inside a UIStackView.
        // The weak box breaks the construction cycle: SwiftUI captures the
        // box first, then the controller is installed before `.view` is loaded
        // and the representable is materialized.
        let box = APSKHostingControllerBox()
        let observed = AnyView(
            sized.background(
                APSKHostingWindowObserver(box: box)
                    .frame(width: 0, height: 0)
            )
        )
        let controller = APSKAttachingHostingController(rootView: observed)
        box.controller = controller
        if #available(iOS 16.0, *) {
            controller.sizingOptions = [.intrinsicContentSize]
        }
        let hostedView = controller.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        platformView = hostedView
        lifetimeOwner = controller
        #else
        // NSHostingView is the AppKit-native shortcut: the view *is* the
        // SwiftUI surface, reports `intrinsicContentSize` accurately to
        // NSStackView's gravity-areas distribution out of the box, and
        // saves us from `NSHostingController.sizingOptions` ordering
        // bugs. The view is a +0-retain NSView; ObjC.owned on the
        // Crystal side bumps it to +1 immediately.
        let hostingView = NSHostingView(rootView: sized)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        platformView = hostingView
        lifetimeOwner = hostingView
        #endif

        // Keep the lifetime owner pinned for as long as the platform
        // view lives. On AppKit they are the same object, but the
        // association is cheap and uniform across platforms. On UIKit
        // the returned hosting view is controller-owned, so the association
        // is the lifetime edge that keeps the controller alive.
        if let owner = lifetimeOwner {
            objc_setAssociatedObject(
                platformView,
                &kHostingControllerKey,
                owner,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        return platformView
    }
}

/// SwiftUI representable wrapping an already-hosted platform view.
/// Container facades (TabView, Form, List) use this to compose child
/// widgets that the Crystal renderer has already built and handed to Swift
/// as raw platform pointers.
#if os(watchOS)
// watchOS: a "hosted child" is the box's SwiftUI content, composed directly into
// the parent's SwiftUI tree (no UIViewRepresentable bridge). Observed so an
// in-place `content` swap on the boundary node (reconcile) re-renders the child
// while it stays mounted — the focus-preserving update channel.
struct APSKHostedChild: View {
    @ObservedObject var view: APSKWatchHostView
    var body: some View { view.content }
}
#elseif canImport(UIKit)
struct APSKHostedChild: UIViewRepresentable {
    let view: APSKPlatformView
    func makeUIView(context: Context) -> APSKPlatformView { view }
    func updateUIView(_: APSKPlatformView, context: Context) {}
}
#elseif canImport(AppKit)
struct APSKHostedChild: NSViewRepresentable {
    let view: APSKPlatformView
    func makeNSView(context: Context) -> APSKPlatformView { view }
    func updateNSView(_: APSKPlatformView, context: Context) {}
}
#endif
