// PopoverOverrides — per-Popover overrides above ViewOverrides.
//
// Field semantics:
//   isPresented       : NSNumber bool. nil = false.
//   arrowEdge         : "top" | "bottom" | "leading" | "trailing".
//                       nil = SwiftUI default (system chooses).
//   preferredWidth    : NSNumber pt. nil = content-driven.
//   preferredHeight   : NSNumber pt. nil = content-driven.

import Foundation

@objc(APSKPopoverOverrides)
public class PopoverOverrides: ViewOverrides {
    @objc public var isPresented: NSNumber? = nil
    @objc public var arrowEdge: String? = nil
    @objc public var preferredWidth: NSNumber? = nil
    @objc public var preferredHeight: NSNumber? = nil
    // Phase 5 v2 — Apple semantic material key. nil → use the per-widget
    // HIG default ("popover"); "system_resolved" → no .presentationBackground.
    @objc public var materialSemantic: String? = nil
    // Phase 10D-polish iter 2 (B-POPOVER-ANCHOR-VIEW) — when set, the
    // facade uses `UIPopoverPresentationController` with this UIView as
    // `sourceView` so the popover bubble's arrow points at it. The
    // value boxes an `unsafeBitCast(ptr, to: UIView.self)` taken at
    // visit time. nil → fall back to SwiftUI's default centered
    // presentation (no arrow).
    @objc public var anchorSourceView: AnyObject? = nil

    @objc public override init() { super.init() }
}
