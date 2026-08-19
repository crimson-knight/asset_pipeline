// ButtonOverrides — per-Button overrides above the common ViewOverrides set.
//
// Field semantics:
//
//   role          : "default" | "destructive" | "cancel". nil = "default".
//                   "destructive" maps to SwiftUI's ButtonRole.destructive
//                   (red emphasis); "cancel" maps to a semibold label per HIG.
//   style         : "automatic" (nil) | "prominent" | "tinted" | "bordered" |
//                   "borderless". The Swift facade applies the corresponding
//                   buttonStyle modifier; nil lets SwiftUI pick per context.
//   fontWeight    : raw Font.Weight intvalue (regular = 0, ultraLight = -3,
//                   bold = 4, heavy = 5, black = 6). nil = .regular.
//   fontSize      : point size for `.font(.system(size:weight:))` (or the
//                   size of a `.custom(...)` face). nil = SwiftUI body default.
//   fontFamily    : custom font family / PostScript name for
//                   `.font(.custom(name, size:))`. nil or "system" = system
//                   font. Consumers register the TTF first (apsk_register_font).
//   disabled      : NSNumber bool. nil = enabled (SwiftUI default).
//   symbolName    : SF Symbol leading-glyph name; nil = no symbol.

import Foundation

@objc(APSKButtonOverrides)
public class ButtonOverrides: ViewOverrides {
    @objc public var fontWeight: NSNumber? = nil
    @objc public var fontSize: NSNumber? = nil
    @objc public var fontFamily: String? = nil
    @objc public var role: String? = nil
    @objc public var style: String? = nil
    @objc public var disabled: NSNumber? = nil
    @objc public var symbolName: String? = nil
    // Max label lines. nil = single-line (truncating CTA default). 0 = unlimited
    // (wrap), n > 1 = capped wrap. When set, the facade applies `.lineLimit` +
    // `.fixedSize(vertical:)` so a long label wraps to its natural multi-line
    // height instead of truncating inside a fill_horizontal container.
    @objc public var numberOfLines: NSNumber? = nil
    // When the renderer pins this button to fill its container width
    // (UI::View#fill_horizontal), a plain text button centers its label in the
    // wide frame — a row/card-filling label rendered centered instead of leading.
    // `true` makes the facade fill the width and LEADING-align the label (mirrors
    // LabelOverrides.fillHorizontal). nil = default (intrinsic, centered) sizing.
    @objc public var fillHorizontal: NSNumber? = nil
    // Horizontal alignment of the LABEL inside the button's own frame:
    // "leading" | "center" | "trailing". nil = the contextual default above
    // (leading when `fillHorizontal` is set, centered otherwise).
    //
    // WHY THIS FIELD EXISTS. `UI::Button#text_alignment` was a documented
    // Crystal property with no native path — `button.cr` said in as many words
    // "native button renderers currently treat the label as centered" — so on
    // iOS the only thing deciding a label's alignment was `fillHorizontal`,
    // which every full-width call to action sets. Measured on the round-4
    // frames (`00-error-dark`): the capsule spanned x=66..1112 (1046px /
    // 349pt) and the label ink "Try again" ended near x=420, leaving roughly
    // 690px (230pt) of empty fill to its right — on every CTA, every screen,
    // both customers, both appearances.
    //
    // "Leading is deliberate, both are measured" is settled AGAINST by the
    // sibling website the same prospect is looking at:
    //   demo_build/sites/<slug>/public/css/design-system.css:190
    //     .btn{display:inline-flex;align-items:center;justify-content:center}
    //   demo_build/sites/<slug>/public/css/primitives.css .p-btn (same rule)
    // When the app and the site disagree, the site wins, because the prospect
    // sees both and the app is the one that looks broken.
    //
    // nil KEEPS THE OLD BEHAVIOUR ON PURPOSE. A wrapping content button (a
    // tappable thought card whose label is the user's own text) still reads
    // leading without saying anything; only a caller that DECLARES an
    // alignment overrides the contextual default.
    @objc public var labelAlignment: String? = nil

    @objc public override init() { super.init() }
}
