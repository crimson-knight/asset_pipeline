// DynamicColor — the platform color behind a Crystal
// `UI::Color.dynamic(light:, dark:)`.
//
// The color resolves to the light components in a light appearance (Aqua /
// `.light` trait) and to the dark components in a dark appearance (Dark Aqua
// / `.dark` trait). Because it is a dynamic `NSColor` / `UIColor`, SwiftUI
// and AppKit re-resolve it whenever the view's appearance changes, so a view
// that uses it updates when the Mac switches between light and dark.
//
// The ObjC trampoline `apsk_overrides_set_dynamic_color` (swiftkit_bridge.m)
// and the reactive Button setters both build their color here, so there is
// one definition of "which appearance counts as dark".

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@objc(APSKDynamicColor)
public class APSKDynamicColor: NSObject {
    public typealias Components = (r: Double, g: Double, b: Double, a: Double)

    public static func make(light: Components, dark: Components) -> APSKPlatformColor {
        let lightColor = APSKPlatformColor(
            red: CGFloat(light.r), green: CGFloat(light.g),
            blue: CGFloat(light.b), alpha: CGFloat(light.a)
        )
        let darkColor = APSKPlatformColor(
            red: CGFloat(dark.r), green: CGFloat(dark.g),
            blue: CGFloat(dark.b), alpha: CGFloat(dark.a)
        )
        #if canImport(UIKit)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
        #else
        return NSColor(name: nil) { appearance in
            isDark(appearance) ? darkColor : lightColor
        }
        #endif
    }

    /// ObjC entry for `swiftkit_bridge.m`.
    @objc(makeColorWithLightRed:lightGreen:lightBlue:lightAlpha:darkRed:darkGreen:darkBlue:darkAlpha:)
    public static func makeColor(
        lightRed lr: Double, lightGreen lg: Double, lightBlue lb: Double, lightAlpha la: Double,
        darkRed dr: Double, darkGreen dg: Double, darkBlue db: Double, darkAlpha da: Double
    ) -> APSKPlatformColor {
        return make(light: (lr, lg, lb, la), dark: (dr, dg, db, da))
    }

    #if canImport(AppKit) && !canImport(UIKit)
    /// True for the dark appearances (Dark Aqua and its high-contrast and
    /// vibrant variants).
    public static func isDark(_ appearance: NSAppearance) -> Bool {
        let match = appearance.bestMatch(from: [
            .aqua, .darkAqua,
            .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            .vibrantLight, .vibrantDark,
        ])
        switch match {
        case .some(.darkAqua), .some(.accessibilityHighContrastDarkAqua), .some(.vibrantDark):
            return true
        default:
            return false
        }
    }
    #endif
}
