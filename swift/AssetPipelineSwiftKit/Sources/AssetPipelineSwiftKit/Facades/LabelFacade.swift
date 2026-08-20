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
    // ── ONE HELPER, EVERY TEXT-BEARING FACADE (round-7) ──────────────────
    //
    // This used to be a private copy living here and nowhere else, which is
    // exactly how the primary CTA's label came to be the one label in the app
    // that did not grow. `APSKDynamicType` is the shared one; the ceiling and
    // the AppKit branch are unchanged, and the Crystal side reads the same
    // number so a build can publish the size it drew.
    //
    // Reading the environment value here is what makes SwiftUI re-evaluate
    // this body when the setting changes mid-session — the equivalent of
    // `adjustsFontForContentSizeCategory` on the UIKit side. `APSKDynamicType`
    // is a plain type and cannot register that dependency by itself.
    private func scaled(_ points: Double) -> CGFloat {
        _ = dynamicTypeSize
        return APSKDynamicType.size(points)
    }

    // A metric that is not a size. See `APSKDynamicType.metric` — tracking is
    // a signed fraction of a point, so it is neither rounded nor guarded on
    // being positive.
    private func scaledMetric(_ points: Double) -> CGFloat {
        _ = dynamicTypeSize
        return APSKDynamicType.metric(points)
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

    var body: AnyView {
        // ── THE ONE CASE THE `Text` PATH CANNOT DRAW (round-7) ───────────
        //
        // A line ratio BELOW the face's own advance. `.lineSpacing` adds and
        // clamps at zero and `Text` ignores an `NSParagraphStyle`, so this
        // drops to a `UILabel` carrying an attributed string — see
        // `APSKAttributedLabel` for what that costs. THE CALLER DECIDES which
        // mechanism it wants: `lineSpacing` reaches every ratio above the
        // face's own advance and is the cheap path, `lineHeightMultiple`
        // reaches the ones below it and is this one. A label that sets neither
        // — which is almost all of them — keeps the path it had.
        #if canImport(UIKit)
        if let lhm = overrides.lineHeightMultiple, lhm.doubleValue > 0 {
            return AnyView(tightlyLedLabel(CGFloat(lhm.doubleValue)))
        }
        #endif
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
        // TRACKING SCALES WITH THE FACE, AND THE COMMENT ABOVE SAID SO WHILE
        // THE CODE DID NOT (round-7). Tracking arrives as an em fraction
        // resolved at the BASE size — `font.size * -0.015` — so a 36pt hero
        // drawn at 58pt under a 1.6x ceiling carried -0.54pt of tracking where
        // its own ratio asks for -0.87pt: 0.0093em against a published
        // -0.015em, 62% of the intended value, and looser the larger the
        // reader sets their text. `scaledMetric` rather than `scaled` because
        // this value is signed and sub-point.
        if let tr = overrides.tracking, tr.doubleValue != 0 {
            content = AnyView(content.tracking(scaledMetric(tr.doubleValue)))
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

    #if canImport(UIKit)
    // The UIKit twin of the modifier chain above, for the display roles that
    // ask to be led tighter than the face. It reads the SAME override fields;
    // what it cannot borrow is the SwiftUI text modifiers, because none of them
    // reaches a hosted UIView.
    private func tightlyLedLabel(_ ratio: CGFloat) -> some View {
        _ = dynamicTypeSize
        let size = APSKDynamicType.size(
            (overrides.fontSize?.doubleValue).flatMap { $0 > 0 ? $0 : nil } ?? 17.0)
        let weight = uiWeight(overrides.fontWeight?.intValue)
        var resolved = UIFont.systemFont(ofSize: size, weight: weight)
        if let fam = overrides.fontFamily, fam != "system", !fam.isEmpty {
            if let named = UIFont(name: fam, size: size) {
                resolved = named
            } else {
                // Same loud fallback the `Text` path takes: a face the bundle
                // does not carry is reported rather than silently swapped.
                APSKFontDiagnostics.reportMissingFamily(fam)
            }
        }
        let align: NSTextAlignment
        switch overrides.textAlignment {
        case "center":   align = .center
        case "trailing": align = .right
        default:         align = .left
        }
        let label = APSKAttributedLabel(
            text: state.text,
            font: resolved,
            color: overrides.foregroundColor ?? UIColor.label,
            alignment: align,
            lineHeightMultiple: ratio,
            tracking: APSKDynamicType.metric(overrides.tracking?.doubleValue ?? 0),
            numberOfLines: overrides.numberOfLines?.intValue ?? 0
        )
        let frameAlign: Alignment
        switch overrides.textAlignment {
        case "center":   frameAlign = .center
        case "trailing": frameAlign = .trailing
        default:         frameAlign = .leading
        }
        if let pmlw = overrides.preferredMaxLayoutWidth {
            return AnyView(label.frame(width: CGFloat(pmlw.doubleValue), alignment: frameAlign))
        }
        if overrides.fillHorizontal?.boolValue == true {
            return AnyView(label.frame(maxWidth: .infinity, alignment: frameAlign))
        }
        return AnyView(label)
    }

    private func uiWeight(_ raw: Int?) -> UIFont.Weight {
        switch raw {
        case -3: return .ultraLight
        case -2: return .thin
        case -1: return .light
        case 1:  return .medium
        case 2:  return .semibold
        case 3:  return .bold
        case 4:  return .heavy
        case 5:  return .black
        default: return .regular
        }
    }
    #endif
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
