// CommonModifiers — the helper every facade calls at the end of its
// pipeline to apply the `ViewOverrides` fields conditionally. A `nil`
// field means the developer left the Crystal property at its type
// default; the corresponding modifier is skipped so SwiftUI's own
// default treatment shows through.
//
// Modifier ordering is deliberate (see implementation.md §5.4):
//   1. background (color)
//   2. foreground (color / style)
//   3. cornerRadius / clip
//   4. padding (insets)
//   5. border overlay
//   6. shadow
//   7. opacity
//   8. hidden
//   9. frame (min/max width/height)
//   10. accessibility identifier
//   11. accessibility label
//
// Each step wraps the prior `AnyView` so the cascade stays composable.

import SwiftUI

enum CommonModifiers {
    static func apply<V: View>(_ view: V, overrides: ViewOverrides) -> AnyView {
        var current = AnyView(view)

        if let bg = overrides.backgroundColor {
            current = AnyView(current.background(swiftColor(bg)))
        }
        if let fg = overrides.foregroundColor {
            current = AnyView(current.foregroundStyle(swiftColor(fg)))
        }
        if let r = overrides.cornerRadius {
            current = AnyView(current.clipShape(
                RoundedRectangle(cornerRadius: CGFloat(r.doubleValue))
            ))
        }
        if overrides.paddingTop != nil || overrides.paddingLeading != nil
            || overrides.paddingBottom != nil || overrides.paddingTrailing != nil {
            let insets = EdgeInsets(
                top: overrides.paddingTop.map { CGFloat($0.doubleValue) } ?? 0,
                leading: overrides.paddingLeading.map { CGFloat($0.doubleValue) } ?? 0,
                bottom: overrides.paddingBottom.map { CGFloat($0.doubleValue) } ?? 0,
                trailing: overrides.paddingTrailing.map { CGFloat($0.doubleValue) } ?? 0
            )
            current = AnyView(current.padding(insets))
        }
        if let bw = overrides.borderWidth, let bc = overrides.borderColor {
            current = AnyView(current.overlay(
                RoundedRectangle(cornerRadius: CGFloat(overrides.cornerRadius?.doubleValue ?? 0))
                    .stroke(swiftColor(bc), lineWidth: CGFloat(bw.doubleValue))
            ))
        }
        if let sr = overrides.shadowRadius {
            let sc = overrides.shadowColor.map { swiftColor($0) } ?? Color.black.opacity(0.25)
            let sx = overrides.shadowOffsetX.map { CGFloat($0.doubleValue) } ?? 0
            let sy = overrides.shadowOffsetY.map { CGFloat($0.doubleValue) } ?? 0
            current = AnyView(current.shadow(color: sc, radius: CGFloat(sr.doubleValue), x: sx, y: sy))
        }
        if let o = overrides.opacity {
            current = AnyView(current.opacity(o.doubleValue))
        }
        if let h = overrides.hidden, h.boolValue {
            current = AnyView(current.hidden())
        }
        if overrides.minWidth != nil || overrides.minHeight != nil
            || overrides.maxWidth != nil || overrides.maxHeight != nil {
            current = AnyView(current.frame(
                minWidth: overrides.minWidth.map { CGFloat($0.doubleValue) },
                maxWidth: overrides.maxWidth.map { CGFloat($0.doubleValue) },
                minHeight: overrides.minHeight.map { CGFloat($0.doubleValue) },
                maxHeight: overrides.maxHeight.map { CGFloat($0.doubleValue) }
            ))
        }
        if let id = overrides.accessibilityIdentifier {
            current = AnyView(current.accessibilityIdentifier(id))
        }
        if let lbl = overrides.accessibilityLabel {
            current = AnyView(current.accessibilityLabel(Text(lbl)))
        }
        return current
    }

    /// Cross-platform `Color` constructor. SwiftUI's `Color(uiColor:)` and
    /// `Color(nsColor:)` are platform-specific; we route through a single
    /// helper so facade code stays platform-agnostic.
    @inline(__always)
    private static func swiftColor(_ c: APSKPlatformColor) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: c)
        #else
        return Color(nsColor: c)
        #endif
    }
}
