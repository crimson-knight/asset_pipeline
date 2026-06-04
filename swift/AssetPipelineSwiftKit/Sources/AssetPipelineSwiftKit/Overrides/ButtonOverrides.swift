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

    @objc public override init() { super.init() }
}
