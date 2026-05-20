// HostingHelpers — platform-conditional aliases and the single `host(_:)`
// helper every facade routes through to wrap a SwiftUI view in a hosting
// controller and return the controller's `.view` as a raw platform pointer.
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

#if canImport(UIKit)
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
    static func host<V: View>(_ view: V) -> APSKPlatformView {
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
        let lifetimeOwner: AnyObject
        #if canImport(UIKit)
        // UIHostingController + .view is the standard UIKit path.
        // `sizingOptions` is set BEFORE first access to `.view` so the
        // hosted UIView reports the SwiftUI intrinsic size on the first
        // layout pass; the prior order produced a CGSizeZero report and
        // collapsed the button to invisible inside a UIStackView.
        let controller = UIHostingController(rootView: sized)
        if #available(iOS 16.0, *) {
            controller.sizingOptions = [.intrinsicContentSize]
        }
        platformView = controller.view
        platformView.translatesAutoresizingMaskIntoConstraints = false
        platformView.backgroundColor = .clear
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
        // association is cheap and uniform across platforms.
        objc_setAssociatedObject(
            platformView,
            &kHostingControllerKey,
            lifetimeOwner,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return platformView
    }
}

/// SwiftUI representable wrapping an already-hosted platform view.
/// Container facades (TabView, Form, List) use this to compose child
/// widgets that the Crystal renderer has already built and handed to Swift
/// as raw platform pointers.
#if canImport(UIKit)
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
