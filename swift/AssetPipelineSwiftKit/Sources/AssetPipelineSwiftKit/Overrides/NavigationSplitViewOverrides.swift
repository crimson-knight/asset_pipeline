// NavigationSplitViewOverrides — per-NavigationSplitView overrides above
// ViewOverrides.
//
// Field semantics:
//   sidebarWidth     : preferred sidebar column width in points. nil = SwiftUI
//                      default (~270pt on macOS, automatic on iOS).
//   columnVisibility : "all" | "doubleColumn" | "detailOnly".
//                      nil = SwiftUI default (.automatic).

import Foundation

@objc(APSKNavigationSplitViewOverrides)
public class NavigationSplitViewOverrides: ViewOverrides {
    @objc public var sidebarWidth: NSNumber? = nil
    @objc public var columnVisibility: String? = nil

    @objc public override init() { super.init() }
}
