// ListViewOverrides — per-ListView overrides above ViewOverrides.
//
// `UI::ListView` is a sectioned list (`Array(Section)`) where each
// section carries an optional header, an optional footer, and an array
// of item child views. The Crystal Populator flattens all section items
// into a single `childViews` array; the facade slices them back into
// sections using `sectionItemCounts`.
//
// Field semantics:
//   listStyle        : "plain" | "grouped" | "inset" | "insetGrouped"
//                      | "sidebar". Maps to SwiftUI `.listStyle(...)`.
//                      nil → SwiftUI default (`.automatic`).
//   sectionHeaders   : NSArray<NSString *> of per-section headers (empty
//                      string = no header for that section).
//   sectionFooters   : NSArray<NSString *> of per-section footers.
//   sectionItemCounts: NSArray<NSNumber *> giving the number of item
//                      child views per section. The facade slices the
//                      flat childViews using these counts.
//   showsSeparators  : NSNumber? (bool-as-int). nil = use the SwiftUI
//                      default for the chosen list style. Crystal's
//                      `UI::ListView.shows_separators` default is `true`
//                      (matches SwiftUI default); the populator only
//                      emits this when the developer turned separators
//                      off, so the facade only sees `false` here.
//
// Phase 10D-final additions — per-row Mail-app row behavior:
//   rowTapTokens     : NSArray<NSNumber *> of UInt64 row-tap tokens
//                      parallel to the flat childViews array. 0 → no
//                      whole-row tap on that row.
//   moveToken        : NSNumber? — UInt64 string-channel token fired
//                      with "from=N,to=M" payload when the user
//                      long-press-drags a row. nil → drag disabled.
//   leadingActionLabels  : Flat NSArray<NSString *> of leading-swipe
//                          action labels across all rows. Sliced per
//                          row by `leadingActionCounts`.
//   leadingActionIcons   : Parallel flat NSArray<NSString *> of SF
//                          Symbol names; empty string → label-only.
//   leadingActionTokens  : Parallel flat NSArray<NSNumber *> of UInt64
//                          action tokens.
//   leadingActionRoles   : Parallel flat NSArray<NSString *> of role
//                          strings ("default" | "destructive" | "cancel").
//   leadingActionTints   : Parallel flat NSArray<NSString *> of tint
//                          keys ("" | "blue" | "green" | ...).
//   leadingActionCounts  : NSArray<NSNumber *> giving the number of
//                          leading actions for each row (parallel to
//                          childViews).
//   trailing*            : Same five fields for the trailing edge.

import Foundation

@objc(APSKListViewOverrides)
public class ListViewOverrides: ViewOverrides {
    @objc public var listStyle: String? = nil
    @objc public var sectionHeaders: [String] = []
    @objc public var sectionFooters: [String] = []
    @objc public var sectionItemCounts: [NSNumber] = []
    @objc public var showsSeparators: NSNumber? = nil

    // Phase 10D-final — per-row Mail-app row behavior.
    @objc public var rowTapTokens: [NSNumber] = []
    @objc public var moveToken: NSNumber? = nil
    @objc public var leadingActionLabels: [String] = []
    @objc public var leadingActionIcons: [String] = []
    @objc public var leadingActionTokens: [NSNumber] = []
    @objc public var leadingActionRoles: [String] = []
    @objc public var leadingActionTints: [String] = []
    @objc public var leadingActionCounts: [NSNumber] = []
    @objc public var trailingActionLabels: [String] = []
    @objc public var trailingActionIcons: [String] = []
    @objc public var trailingActionTokens: [NSNumber] = []
    @objc public var trailingActionRoles: [String] = []
    @objc public var trailingActionTints: [String] = []
    @objc public var trailingActionCounts: [NSNumber] = []

    // Phase 10D-polish A4 — default horizontal row inset applied via
    // SwiftUI `.listRowInsets(...)`. nil → SwiftUI platform default.
    @objc public var contentInsetHorizontal: NSNumber? = nil

    // Phase 10D-polish A3 — duration (seconds) for row-removal animation.
    // Wrapped in `withAnimation(.easeInOut(duration:))` and a per-row
    // `.transition(.opacity.combined(with: .scale(...)))`. 0 disables.
    @objc public var rowRemovalDurationSeconds: NSNumber? = nil

    // Phase 10D-polish A2 — when true AND moveToken != nil, render a
    // SF Symbol `line.3.horizontal` drag affordance on the trailing
    // edge of each row.
    @objc public var showsDragHandle: NSNumber? = nil

    @objc public override init() { super.init() }
}
