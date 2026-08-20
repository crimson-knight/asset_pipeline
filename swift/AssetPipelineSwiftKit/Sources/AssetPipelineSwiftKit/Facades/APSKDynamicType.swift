import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// ═══════════════════════════════════════════════════════════════════════════
// DYNAMIC TYPE, IN ONE PLACE, FOR EVERY FACADE THAT DRAWS TEXT
// ═══════════════════════════════════════════════════════════════════════════
//
// `Font.system(size:)` and `Font.custom(_:size:)` are FIXED sizes: they do not
// track the reader's text-size setting. A stack that resolves every role to an
// explicit point size therefore draws 18pt at 18pt for a reader who has asked
// the system for accessibility text — unless something scales it.
//
// WHAT WAS MEASURED, AND WHY THIS FILE EXISTS RATHER THAN A SECOND COPY OF THE
// HELPER. `LabelFacade` grew `scaled()` and `@Environment(\.dynamicTypeSize)`
// and nothing else did. Two walks of the same build on the same simulator,
// `xcrun simctl ui <sim> content_size large` then
// `accessibility-extra-extra-extra-large`:
//
//   * masthead brand name  19.0pt → 29.0pt  (1.53x)
//   * page subtitle        15.0pt → 23.0pt  (1.53x)
//   * card body advance    25.0pt → 39.33pt (1.57x)
//   * THE PRIMARY CTA'S LABEL — unchanged. The capsule measured 45.67pt tall
//     in BOTH and the label's ink band 50px / 16.67pt high with the same peak
//     ink in both, i.e. byte-identical rendering.
//
// Net effect at accessibility sizes: the paragraph above the button is 24pt and
// the button's own label is 18pt, so the ONE THING A THUMB CAN ACT ON becomes
// the smallest important type on the screen. `ButtonFacade`, `TextFieldFacade`,
// `TextAreaFacade` and `SecureFieldFacade` all passed `CGFloat(sz)` raw.
//
// So the helper is a type rather than a method on one view: four facades that
// each grew their own copy is how one of them ends up not having one.
enum APSKDynamicType {
    // The ceiling on the scaling. Accessibility sizes run to roughly 3.1x the
    // default on iOS, and a fixed-height chrome band (a tab bar, a 26pt
    // disclosure ribbon) cannot absorb that without the layout coming apart —
    // which would be a worse outcome for the same reader. 1.6x is a little past
    // `.xxLarge` and is where the shipped layouts still hold. It is a cap on the
    // SCALE, not a cap on the size, so every role keeps its ratio to every other
    // one.
    //
    // ONE NUMBER, TWO LANGUAGES: `UI::DYNAMIC_TYPE_MAX_SCALE` in
    // `src/ui/font_registry.cr` is this value, because the Crystal side has to
    // be able to PUBLISH the size that was drawn (see `ui_dynamic_type_scaled`).
    // The consumer that depends on both asserts they agree (happy_coach
    // `spec/demo/component_schema_spec.cr`), so they cannot drift silently.
    static let maxScale: CGFloat = 1.6

    // The reader's current scale, ceiling applied. Reads `UIFontMetrics` for the
    // body text style, which is the same metric a `UIFontMetrics`-scaled UIKit
    // control uses, so scaled Crystal type and any system control on the same
    // screen move together.
    static var scale: CGFloat {
        #if canImport(UIKit)
        let base: CGFloat = 100
        let metric = UIFontMetrics(forTextStyle: .body).scaledValue(for: base)
        return min(metric / base, maxScale)
        #else
        // AppKit has no per-app content-size category; macOS scales at the
        // display level instead, so the point size IS the point size there.
        return 1
        #endif
    }

    // A POINT SIZE, scaled and rounded to a whole point. Rounding is deliberate:
    // a half-point font size produces sub-pixel baselines that make two labels
    // of the same role measure differently on a frame.
    static func size(_ points: Double) -> CGFloat {
        let base = CGFloat(points)
        guard base > 0 else { return base }
        return (base * scale).rounded()
    }

    // A METRIC THAT IS NOT A SIZE — tracking, line spacing, a bar height.
    //
    // Two differences from `size(_:)` and both are defects it would otherwise
    // cause. It does NOT round, because tracking is a fraction of a point and
    // rounding it to a whole point destroys it; and it does not bail out on a
    // non-positive input, because tracking is usually NEGATIVE — the site
    // publishes `--display-track:-.015em` on every heading — and a
    // `guard base > 0` returns such a value completely unscaled.
    static func metric(_ points: Double) -> CGFloat {
        CGFloat(points) * scale
    }
}
