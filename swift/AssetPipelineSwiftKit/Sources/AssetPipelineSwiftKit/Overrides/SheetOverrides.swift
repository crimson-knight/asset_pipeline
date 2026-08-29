// SheetOverrides — per-Sheet overrides above ViewOverrides.
//
// Field semantics:
//   isPresented         : NSNumber bool. nil = false (sheet not presented).
//   surfaceStyle        : "auto" | "grouped_card" | "plain". nil = "auto".
//   detents             : NSArray<NSString *> — "small" | "medium" | "large".
//                         nil/empty = SwiftUI default.
//   showsDragIndicator  : NSNumber bool. nil = SwiftUI default (true).

import Foundation

@objc(APSKSheetOverrides)
public class SheetOverrides: ViewOverrides {
    @objc public var isPresented: NSNumber? = nil
    @objc public var surfaceStyle: String? = nil
    @objc public var detents: [String] = []
    @objc public var showsDragIndicator: NSNumber? = nil
    // Phase 10D-polish iter 2 (B-SHEET-INTERACTIVE-DISMISS-DISABLED) —
    // when true, the facade applies `.interactiveDismissDisabled()` so
    // the user cannot swipe-to-dismiss the sheet. nil = false.
    @objc public var interactiveDismissDisabled: NSNumber? = nil
    // Phase 5 v2 — Apple semantic material key (snake_case). nil → use the
    // per-widget HIG default ("sheet"); "system_resolved" → no
    // .presentationBackground() modifier (let Apple defaults apply).
    @objc public var materialSemantic: String? = nil

    // ------------------------------------------------------------------
    // Usability-bar motion control (platform-capability-matrix.md §1, U1–U3).
    //
    // BEFORE this field set, `SheetFacade` drove present/dismiss with bare
    // `.sheet(isPresented:)` and SwiftUI's implicit animation — there was no
    // duration, no spring, no floor, and no reduce-motion path. A Rerender
    // that re-seeded `isPresented` true→true could collapse the transition to
    // no perceptible motion. That is exactly the "too-fast sheet" false-pass
    // (U1/U4). These fields let the library *bound* the transition.
    //
    //   presentDurationMs : NSNumber (ms). nil → MotionScale base (240ms,
    //                       baked AssetPipelineTokens.Motion.durationBase).
    //                       Clamped by the facade to [U1 floor, U1 ceiling].
    //   useSpring         : NSNumber bool. nil/true → spring present/dismiss
    //                       (HIG-idiomatic). false → eased curve of the
    //                       resolved duration.
    //   reduceMotion      : NSNumber bool. nil → honor the system environment
    //                       (\.accessibilityReduceMotion). true/false → force.
    //                       When effective, the transition becomes a short
    //                       *crossfade* (U2: fade, never a kill / instant snap).
    // ------------------------------------------------------------------
    @objc public var presentDurationMs: NSNumber? = nil
    @objc public var useSpring: NSNumber? = nil
    @objc public var reduceMotion: NSNumber? = nil

    @objc public override init() { super.init() }
}
