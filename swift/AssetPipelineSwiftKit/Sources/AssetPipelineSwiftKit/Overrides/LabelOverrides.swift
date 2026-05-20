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

import Foundation

@objc(APSKLabelOverrides)
public class LabelOverrides: ViewOverrides {
    @objc public var labelRole: String? = nil
    @objc public var textAlignment: String? = nil
    @objc public var numberOfLines: NSNumber? = nil

    @objc public override init() { super.init() }
}
