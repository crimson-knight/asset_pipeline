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

    @objc public override init() { super.init() }
}
