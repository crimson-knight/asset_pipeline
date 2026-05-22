// GlassBackgroundFacade — SwiftUI bridge for UI::GlassBackground, the
// Phase 3 "headline visual differentiator" the README names. On iOS 26 /
// macOS 26 (the Liquid Glass SDKs) the facade routes through
// `.glassBackgroundEffect()`; on the pre-26 OSes (iOS 16..25 / macOS
// 13..25) it falls back to the matching static Material so the surface
// still tracks appearance correctly.
//
// Phase 5 will extend this facade with the full material parameter set
// (intensity, tint, corner curve). The Phase 3 wiring is the platform
// floor: a developer who writes `UI::GlassBackground.new(content)` gets
// real Liquid Glass on iOS 26 today, with no extra knobs.
//
// Brand identity: `GlassBackground` deliberately does NOT apply the
// brand tint (Apple convention — glass surfaces accept system accent
// only). The `.tint()` cascade in `HostingHelpers.host(_:)` propagates
// the brand colour to interactive descendants inside the glass surface;
// the glass material itself stays neutral.

import SwiftUI
import Foundation

@objc(APSKGlassBackgroundFacade)
public final class GlassBackgroundFacade: NSObject {
    /// Build the glass-backed platform view. `childView` is the already-
    /// hosted Crystal child (the content placed behind the glass). When
    /// `nil`, the facade renders an empty glass card.
    @objc public static func makeGlassBackground(
        overrides: GlassBackgroundOverrides,
        childView: APSKPlatformView?
    ) -> APSKPlatformView {
        // Embed the Crystal child via APSKHostedChild so it participates
        // in SwiftUI layout. When no child is supplied we render a clear
        // expanding rectangle so the glass surface has something to back.
        let materialKey = overrides.material ?? "regular"

        let backed: AnyView
        if #available(iOS 26.0, macOS 26.0, *) {
            // Liquid Glass — the actual headline visual differentiator.
            // `.glassEffect()` is the iOS 26 / macOS 26 SwiftUI modifier
            // that produces the genuine Apple liquid-glass material with
            // the system's automatic appearance + Dynamic Type response.
            //
            // PHASE 5 CONTRACT NOTE: The iOS 26+ Liquid Glass path does NOT
            // vary by `materialKey` step — every step renders the system
            // Liquid Glass treatment Apple's HIG selects. This matches the
            // brief.yml adapter_cardinality row 1 contract ("intensity 1.3
            // quantizes to .regularMaterial on Apple, visually IDENTICAL
            // to default intensity 1.0"). The pre-26 `.background(Material)`
            // fallback below DOES vary by step. Brands wanting a per-step
            // differentiation that survives onto iOS 26+ must either rely
            // on the system's automatic treatment (the HIG-canonical
            // behavior) or target the web / Android renderers where the
            // step is render-side and intensity scales blur continuously.
            _ = materialKey  // explicitly unused on the Liquid Glass path
            backed = AnyView(
                hostedChild(childView)
                    .glassEffect()
            )
        } else {
            // Pre-26 fallback. `Material` is a static SwiftUI background
            // style; it tracks light/dark appearance but lacks the
            // dynamic light bending of Liquid Glass.
            let material: Material = {
                switch materialKey {
                case "thin":       return .thinMaterial
                case "thick":      return .thickMaterial
                case "ultraThin":  return .ultraThinMaterial
                case "ultraThick": return .ultraThickMaterial
                default:           return .regularMaterial
                }
            }()
            backed = AnyView(
                hostedChild(childView)
                    .background(material)
            )
        }

        let composed = CommonModifiers.apply(backed, overrides: overrides)
        return HostingHelpers.host(composed)
    }

    /// Wrap the platform-view child in `APSKHostedChild` (or an empty
    /// rectangle when absent). Returning an `AnyView` keeps the iOS 26 /
    /// fallback branches both type-erased to the same shape.
    @ViewBuilder
    private static func hostedChild(_ child: APSKPlatformView?) -> some View {
        if let child = child {
            APSKHostedChild(view: child)
        } else {
            Rectangle().fill(Color.clear)
        }
    }
}
