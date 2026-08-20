// LabelOverrides — per-Label overrides above the common ViewOverrides set.
//
// Field semantics (all nil = SwiftUI default):
//
//   labelRole       : "primary" | "secondary" | "tertiary" | "quaternary" — maps
//                     to SwiftUI semantic colours (`.primary`, `.secondary`,
//                     etc.). Mutually exclusive with the `foregroundColor`
//                     RGBA override on ViewOverrides — when both are set,
//                     foregroundColor wins.
//   textAlignment   : "leading" | "center" | "trailing" | "fill" — SwiftUI
//                     `multilineTextAlignment` modifier.
//   numberOfLines   : line cap (0 = unlimited / SwiftUI default).
//   fontSize        : point size for `.font(.system(size:weight:))`. nil = use
//                     SwiftUI body default. The Crystal `UI::Font.size`
//                     property is forwarded through here so a brand wordmark
//                     can render at h1-bold display size while still tracking
//                     Dynamic Type.
//   fontWeight      : raw `Font.Weight` int rawValue (regular = 0, ultraLight
//                     = -3, bold = 3, heavy = 4, black = 5). nil = .regular.
//                     Matches the convention ButtonOverrides already uses.

import Foundation

@objc(APSKLabelOverrides)
public class LabelOverrides: ViewOverrides {
    @objc public var labelRole: String? = nil
    @objc public var textAlignment: String? = nil
    @objc public var numberOfLines: NSNumber? = nil
    @objc public var fontSize: NSNumber? = nil
    @objc public var fontWeight: NSNumber? = nil
    // Custom font family / PostScript name for `.font(.custom(name, size:))`.
    // nil or "system" = the system font. Consumers register the TTF first
    // (apsk_register_font). Use the PostScript name (e.g. "Alegreya-Medium") for
    // an exact weight/face — custom fonts don't reliably honour `.fontWeight()`.
    @objc public var fontFamily: String? = nil
    // Phase 6.11 — strikethrough toggle. nil = SwiftUI default (no
    // strikethrough); `true` applies `.strikethrough(true)` so completed
    // todo rows render with a HIG-correct line through the title.
    @objc public var strikethrough: NSNumber? = nil
    // When the renderer pins this label to fill its container width
    // (UI::View#fill_horizontal), the SwiftUI Text otherwise centers in the
    // wide hosting view — a full-width title/subtitle rendered centered instead
    // of leading. `true` makes the facade apply `.frame(maxWidth: .infinity,
    // alignment:)` so the text fills the width and aligns per textAlignment
    // (default leading). nil = no fill frame (SwiftUI default sizing).
    @objc public var fillHorizontal: NSNumber? = nil
    // Explicit wrapping width. When set, the facade pins the label to exactly
    // this width (`.frame(width:)`) so SwiftUI computes the correct WRAPPED
    // height for that width — which the NSHostingView then reports to the
    // NSStackView. Without it, a fill_horizontal label reports its single-line
    // ideal height (the maxWidth:.infinity frame never wraps at fitting-size
    // time), so a multi-line label under-reserves height and the next stacked
    // element overlaps it. Set this to the known container content width on
    // screens whose labels wrap dynamic content. Takes precedence over
    // fillHorizontal. nil = SwiftUI default sizing.
    @objc public var preferredMaxLayoutWidth: NSNumber? = nil
    // Extra points inserted between wrapped lines (`SwiftUI .lineSpacing`).
    // nil = the face's own default advance, which is what every label rendered
    // before this field existed. It is what lets a 36pt display headline be led
    // at ~1.06 while a 15pt paragraph is led at ~1.55 — the two values a design
    // system's own stylesheet publishes and this stack could previously express
    // neither of.
    @objc public var lineSpacing: NSNumber? = nil
    // Letter spacing in points (`SwiftUI .tracking`). nil / 0 = the face's own
    // default. Carried from `UI::Font#tracking`.
    @objc public var tracking: NSNumber? = nil
    // Line height as a RATIO of the font size (`NSParagraphStyle
    // .lineHeightMultiple`). nil = the face's own advance.
    //
    // This is the half `lineSpacing` cannot express. SwiftUI's `.lineSpacing`
    // ADDS points and clamps at zero, so a ratio ABOVE the face's own ~1.195
    // is reachable and one BELOW it is not — while every display ramp in the
    // field asks for exactly that (`.p-h1,.p-h2,.p-h3{line-height:1.06}`). A
    // value below 1.0 therefore switches this label onto the UIKit path, where
    // an `NSAttributedString` paragraph style honours it; see
    // `APSKAttributedLabel`.
    @objc public var lineHeightMultiple: NSNumber? = nil

    @objc public override init() { super.init() }
}
