// SwipeActionRowOverrides — per-SwipeActionRow overrides above
// ViewOverrides.
//
// Phase 10D-refocus — SwiftUI `.swipeActions(edge:)` bridge for the
// Voyager todos screen. The Crystal-side `UI::SwipeActionRow.visit`
// path previously emitted a custom horizontal-scroll UIView (the
// `make_swipe_reveal_row` ObjC helper) that surfaced actions as always-
// visible inline buttons. That contract was not what the owner
// requested in the hand-test: the desired behavior is the SwiftUI Mail-
// style swipe gesture where actions appear as full-row-height tiles
// that slide out from the edge in response to a pan.
//
// SwiftUI `.swipeActions` requires the row to live inside a
// `SwiftUI.List`, so this facade wraps the single hosted content view
// in a `List { ... }` with chrome stripped (no separators, no
// background, no insets) so the row visually matches whatever the
// surrounding stack expects.
//
// Field semantics — all arrays are parallel; index `i` describes
// action `i`:
//   leadingLabels  : leading-edge action labels (rendered when user
//                    swipes left-to-right).
//   leadingIcons   : optional SF Symbol names parallel to leadingLabels.
//                    Empty string entries → label-only.
//   leadingTokens  : UInt64 action tokens; 0 → no-op.
//   leadingRoles   : "default" | "destructive" | "cancel".
//   leadingTints   : "" | "blue" | "green" | "orange" | "red" | "purple"
//                    | "yellow" — system tint key. Empty → SwiftUI
//                    default (system blue for default role, system red
//                    for destructive role).
//   trailing*      : same set for trailing-edge actions.
//   rowWidth       : optional width pin (NSNumber Double); when set we
//                    apply `.frame(width:)` so the row matches the
//                    surrounding stack's content_width.

import Foundation

@objc(APSKSwipeActionRowOverrides)
public class SwipeActionRowOverrides: ViewOverrides {
    @objc public var leadingLabels: [String] = []
    @objc public var leadingIcons: [String] = []
    @objc public var leadingTokens: [NSNumber] = []
    @objc public var leadingRoles: [String] = []
    @objc public var leadingTints: [String] = []
    @objc public var trailingLabels: [String] = []
    @objc public var trailingIcons: [String] = []
    @objc public var trailingTokens: [NSNumber] = []
    @objc public var trailingRoles: [String] = []
    @objc public var trailingTints: [String] = []
    @objc public var rowWidth: NSNumber? = nil

    @objc public override init() { super.init() }
}
