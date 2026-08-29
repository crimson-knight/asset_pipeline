// LabelFacade — SwiftUI Text(_:) bridge.
//
// Default (empty LabelOverrides): system body font, `.primary` foreground
// (Apple-tracking light/dark), `.leading` alignment, unlimited line wrap.
// Overrides surface only via the ViewOverrides cascade or the
// LabelOverrides knobs (semantic role, alignment, line cap).
//
// Phase 3 Remediation 4: the facade now holds an `APSKLabelState`
// `@ObservedObject` so Crystal-side `text=` mutations propagate to the
// rendered SwiftUI body. The caller (Crystal renderer) writes the state
// pointer back through the `outState` UnsafeMutablePointer so it can later
// dispatch `apsk_label_set_text` to mutate `state.text`.

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@objc(APSKLabelFacade)
public class LabelFacade: NSObject {
    /// Static-construction entry point retained for back-compat. Renderers
    /// that don't yet need a reactive label path keep calling this and
    /// receive a non-observable label exactly as before Remediation 4.
    @objc public static func makeLabel(
        text: String,
        overrides: LabelOverrides
    ) -> APSKPlatformView {
        return makeReactiveLabel(
            text: text, overrides: overrides, outState: nil
        )
    }

    /// Reactive-construction entry. When `outState` is non-nil the facade
    /// allocates an `APSKLabelState`, retains it with `passRetained`, writes
    /// the opaque pointer through `outState`, and binds the SwiftUI body to
    /// observe `state.text`.
    ///
    /// `outState` is nullable so the legacy non-reactive path can route
    /// through the same implementation without forcing every call-site to
    /// allocate an out-parameter slot.
    @objc public static func makeReactiveLabel(
        text: String,
        overrides: LabelOverrides,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        let state = APSKLabelState(text: text)

        // Hand the +1 retain to Crystal. The state object stays alive
        // until `apsk_state_release` drops the retain (driven by
        // NativeHandle#release! on the Crystal side).
        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(state).toOpaque()
        }

        let body = APSKLabelHost(state: state, overrides: overrides)
        return HostingHelpers.host(body)
    }
}

// Hosted SwiftUI view that observes the label state and rebuilds its
// modifier chain on every published change. The modifier chain is the
// same one the previous static facade applied, lifted into a `var body`
// so SwiftUI can re-evaluate it.
private struct APSKLabelHost: View {
    @ObservedObject var state: APSKLabelState
    let overrides: LabelOverrides

    // ── DYNAMIC TYPE ──────────────────────────────────────────────────────
    //
    // READ, NOT IGNORED. `Font.system(size:)` and `Font.custom(_:size:)` are
    // FIXED sizes: they do not track the reader's text-size setting, so a
    // stack that resolves every role to an explicit point size draws 11pt
    // small labels at 11pt for a reader who has asked the system for large
    // text. There was no `UIFontMetrics`, no `preferredFont(forTextStyle:)`
    // and no `adjustsFontForContentSizeCategory` anywhere in this renderer,
    // the ObjC bridge or the host — count zero.
    //
    // Declaring the environment value here does two jobs at once: it gives the
    // scaled size below its input, and it makes SwiftUI re-evaluate this body
    // when the setting changes mid-session, which is what
    // `adjustsFontForContentSizeCategory` buys on the UIKit side.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // The ceiling on that scaling. Accessibility sizes run to roughly 3.1x the
    // default on iOS, and a fixed-height chrome band (a tab bar, a 26pt
    // disclosure ribbon) cannot absorb that without the layout coming apart —
    // which would be a worse outcome for the same reader. 1.6x is a little past
    // `.xxLarge` and is where the shipped layouts still hold. It is a cap on
    // the SCALE, not a cap on the size, so every role keeps its ratio to every
    // other one.
    private static let maxDynamicTypeScale: CGFloat = 1.6

    private func scaled(_ points: Double) -> CGFloat {
        let base = CGFloat(points)
        guard base > 0 else { return base }
        #if canImport(UIKit)
        let metric = UIFontMetrics(forTextStyle: .body).scaledValue(for: base)
        let ratio = min(metric / base, Self.maxDynamicTypeScale)
        return (base * ratio).rounded()
        #else
        // AppKit has no per-app content-size category; macOS scales at the
        // display level instead, so the point size IS the point size there.
        return base
        #endif
    }

    // Is this family actually loadable? `.custom(name:size:)` does NOT fail
    // when the name is unknown — it silently resolves to the system face, which
    // is a bold brand headline turning into regular San Francisco with nothing
    // anywhere reporting it. Asking UIFont first is the only way to know.
    private func familyIsLoadable(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: name, size: 12.0) != nil
        #else
        return NSFont(name: name, size: 12.0) != nil
        #endif
    }

    var body: some View {
        var content: AnyView = AnyView(Text(state.text))

        // Font size + weight. Apply `.font(.system(size:weight:))` when
        // a Crystal-side `UI::Font.size` / `UI::Font.weight` override
        // surfaces. Without this the Crystal `Font` value was silently
        // dropped on the floor and every Label rendered at SwiftUI's
        // body default (~17pt regular), which is why the Phase 6
        // sign-in "Cascade" wordmark looked identical in weight and
        // size to the subtitle below it. The weight rawValue mapping
        // mirrors ButtonOverrides' convention.
        let resolvedWeight: Font.Weight = {
            if let w = overrides.fontWeight { return Font.Weight(rawValue: w.intValue) ?? .regular }
            return .regular
        }()
        if let fam = overrides.fontFamily, fam != "system", !fam.isEmpty {
            // Custom registered font (e.g. "Alegreya-Medium"). Use the
            // PostScript name for an exact weight/face. Size: the explicit
            // fontSize, else SwiftUI body default (~17).
            let sz = (overrides.fontSize?.doubleValue).flatMap { $0 > 0 ? $0 : nil } ?? 17.0
            if familyIsLoadable(fam) {
                content = AnyView(content.font(.custom(fam, size: scaled(sz))))
            } else {
                // A MISSING FACE IS LOUD AND KEEPS ITS WEIGHT. The old
                // behaviour here was to hand `.custom` a name SwiftUI could not
                // resolve, which drew regular San Francisco with no log, no
                // raise and no gate arm — bundle a face under one PostScript
                // name, ship it under another, and every bold headline in every
                // customer's app silently loses both its face AND its weight
                // while the whole suite stays green.
                APSKFontDiagnostics.reportMissingFamily(fam)
                content = AnyView(content.font(.system(size: scaled(sz), weight: resolvedWeight)))
            }
        } else if let sz = overrides.fontSize, sz.doubleValue > 0 {
            let weight = resolvedWeight
            content = AnyView(content.font(.system(size: scaled(sz.doubleValue), weight: weight)))
        } else if let w = overrides.fontWeight {
            // No explicit size but explicit weight — keep the body
            // font and just override the weight via `.fontWeight()`.
            let weight = Font.Weight(rawValue: w.intValue) ?? .regular
            content = AnyView(content.fontWeight(weight))
        }

        switch overrides.labelRole {
        case "primary":
            content = AnyView(content.foregroundStyle(.primary))
        case "secondary":
            content = AnyView(content.foregroundStyle(.secondary))
        case "tertiary":
            content = AnyView(content.foregroundStyle(.tertiary))
        case "quaternary":
            content = AnyView(content.foregroundStyle(.quaternary))
        default:
            break
        }

        switch overrides.textAlignment {
        case "leading":  content = AnyView(content.multilineTextAlignment(.leading))
        case "center":   content = AnyView(content.multilineTextAlignment(.center))
        case "trailing": content = AnyView(content.multilineTextAlignment(.trailing))
        default: break
        }

        if let n = overrides.numberOfLines, n.intValue > 0 {
            content = AnyView(content.lineLimit(n.intValue))
        }

        // Leading and tracking. Applied after the font so both observe the
        // resolved face and size, and scaled alongside it so a line that is
        // led at 1.55x stays led at 1.55x when the reader enlarges the text.
        if let ls = overrides.lineSpacing, ls.doubleValue >= 0 {
            content = AnyView(content.lineSpacing(scaled(ls.doubleValue)))
        }
        if let tr = overrides.tracking, tr.doubleValue != 0 {
            content = AnyView(content.tracking(CGFloat(tr.doubleValue)))
        }

        // Phase 6.11 — strikethrough modifier. Applied last among the
        // text-shaping modifiers so it observes the resolved font + color.
        if let st = overrides.strikethrough, st.boolValue {
            content = AnyView(content.strikethrough(true))
        }

        // fill_horizontal: the renderer pins the hosting view wide; without a
        // maxWidth frame the SwiftUI Text centers in it (a full-width title or
        // subtitle rendered centered instead of leading). Fill the width and
        // position the text per textAlignment — default leading.
        //
        // `.fixedSize(horizontal: false, vertical: true)` is the key for WRAPPING:
        // the NSHostingView computes its intrinsic height at the Text's one-line
        // ideal width BEFORE the equal-width constraint pins it wider, so a long
        // subtitle truncated to a single line. fixedSize(vertical:) forces the
        // Text to take its natural multi-line height for the proposed width, so it
        // wraps and grows instead of truncating. Harmless on single-line labels.
        if overrides.fillHorizontal?.boolValue == true || overrides.preferredMaxLayoutWidth != nil {
            let frameAlign: Alignment
            switch overrides.textAlignment {
            case "center":   frameAlign = .center
            case "trailing": frameAlign = .trailing
            default:         frameAlign = .leading
            }
            if let pmlw = overrides.preferredMaxLayoutWidth {
                // Explicit width → SwiftUI computes the correct WRAPPED height at
                // this width, so the NSHostingView reports multi-line height to
                // the NSStackView and the next stacked element no longer overlaps
                // a wrapped label. (A bare `.frame(maxWidth:.infinity)` reports the
                // single-line ideal height at fitting-size time — the root of the
                // long-standing fill-label-height under-reservation bug.) Takes
                // precedence over fillHorizontal.
                content = AnyView(
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: CGFloat(pmlw.doubleValue), alignment: frameAlign)
                )
            } else {
                content = AnyView(
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: frameAlign)
                )
            }
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return content
    }
}

// Local `Font.Weight` rawValue init. Matches the convention used by
// ButtonFacade.swift so Crystal's `populate_label` and `populate_button`
// can emit the same integer rawValues for the same Crystal weight
// Symbols.
private extension Font.Weight {
    init?(rawValue: Int) {
        switch rawValue {
        case -3: self = .ultraLight
        case -2: self = .thin
        case -1: self = .light
        case 0: self = .regular
        case 1: self = .medium
        case 2: self = .semibold
        case 3: self = .bold
        case 4: self = .heavy
        case 5: self = .black
        default: return nil
        }
    }
}
