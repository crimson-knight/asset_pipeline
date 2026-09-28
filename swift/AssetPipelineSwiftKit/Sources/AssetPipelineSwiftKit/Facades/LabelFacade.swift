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
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
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
        // A label that does not fill its row hugs its text, so the row gives its
        // slack to a filling sibling instead of stretching the label.
        let fillsWidth = overrides.fillHorizontal?.boolValue == true
        return HostingHelpers.host(body, wrapsText: true, hugsWidth: !fillsWidth)
    }
}

// Hosted SwiftUI view that observes the label state and rebuilds its
// modifier chain on every published change. The modifier chain is the
// same one the previous static facade applied, lifted into a `var body`
// so SwiftUI can re-evaluate it.
private struct APSKLabelHost: View {
    @ObservedObject var state: APSKLabelState
    let overrides: LabelOverrides

    // The link a trailing link carries when it has no URL of its own. Its
    // click is always answered by the handler or discarded, never opened.
    private static let handlerOnlyLinkURL = URL(string: "apsk-label-link:trailing")!

    // The label text, followed by the inline trailing link when one is set.
    // One Text keeps the link on the paragraph's lines, so it wraps with it
    // and VoiceOver reads it as a link inside the text.
    private var labelText: Text {
        guard let linkText = overrides.trailingLinkText, !linkText.isEmpty else {
            return Text(state.text)
        }
        var attributed = AttributedString(state.text.isEmpty ? "" : state.text + " ")
        var link = AttributedString(linkText)
        link.link = overrides.trailingLinkUrl.flatMap(URL.init(string:)) ?? Self.handlerOnlyLinkURL
        link.underlineStyle = .single
        attributed.append(link)
        return Text(attributed)
    }

    var body: some View {
        var content: AnyView = AnyView(labelText)

        // Font size + weight. Apply `.font(.system(size:weight:))` when
        // a Crystal-side `UI::Font.size` / `UI::Font.weight` override
        // surfaces. Without this the Crystal `Font` value was silently
        // dropped on the floor and every Label rendered at SwiftUI's
        // body default (~17pt regular), which is why the Phase 6
        // sign-in "Cascade" wordmark looked identical in weight and
        // size to the subtitle below it. The weight rawValue mapping
        // mirrors ButtonOverrides' convention.
        if let fam = overrides.fontFamily, fam != "system", !fam.isEmpty {
            // Custom registered font (e.g. "Alegreya-Medium"). Use the
            // PostScript name for an exact weight/face. Size: the explicit
            // fontSize, else SwiftUI body default (~17).
            let sz = (overrides.fontSize?.doubleValue).flatMap { $0 > 0 ? $0 : nil } ?? 17.0
            if fam == "monospace" {
                content = AnyView(content.font(.system(size: CGFloat(sz), weight: .regular, design: .monospaced)))
            } else {
                content = AnyView(content.font(.custom(fam, size: CGFloat(sz))))
            }
        } else if let sz = overrides.fontSize, sz.doubleValue > 0 {
            let weight: Font.Weight
            if let w = overrides.fontWeight {
                weight = Font.Weight(rawValue: w.intValue) ?? .regular
            } else {
                weight = .regular
            }
            content = AnyView(content.font(.system(size: CGFloat(sz.doubleValue), weight: weight)))
        } else if let w = overrides.fontWeight {
            // No explicit size but explicit weight — keep the body
            // font and just override the weight via `.fontWeight()`.
            let weight = Font.Weight(rawValue: w.intValue) ?? .regular
            content = AnyView(content.fontWeight(weight))
        }

        // Letter tracking in points. `.tracking(_:)` on the view reaches the
        // Text through the environment, so it composes with every font path
        // above (system, weight-only, monospaced, custom registered family)
        // and keeps the Text one string for VoiceOver, selection and wrapping.
        if let tracking = overrides.tracking {
            content = AnyView(content.tracking(CGFloat(tracking.doubleValue)))
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

        if let lineHeight = overrides.lineHeight?.doubleValue, lineHeight > 0 {
            let natural = APSKLabelLineMetrics.naturalLineHeight(for: overrides)
            let extra = max(0, CGFloat(lineHeight) - natural)
            if extra > 0 {
                content = AnyView(content.lineSpacing(extra))
            }
        }

        if let n = overrides.numberOfLines, n.intValue > 0 {
            content = AnyView(content.lineLimit(n.intValue))
        }

        // Phase 6.11 — strikethrough modifier. Applied last among the
        // text-shaping modifiers so it observes the resolved font + color.
        if let st = overrides.strikethrough, st.boolValue {
            content = AnyView(content.strikethrough(true))
        }

        // Where the text sits when its frame is wider than the text: a
        // fill_horizontal label the renderer pins wide, a label pinned to a
        // minimum/maximum width column, or a label a required stack constraint
        // stretches. Without an aligned frame the SwiftUI Text centers in that
        // space. Position it per textAlignment, default leading.
        let frameAlign: Alignment
        switch overrides.textAlignment {
        case "center":   frameAlign = .center
        case "trailing": frameAlign = .trailing
        default:         frameAlign = .leading
        }
        // The aligning outer frames below are for a label hosted in a platform
        // view, whose hosting view reports only the ideal width to the stack.
        // On watchOS the whole tree is SwiftUI, where a maxWidth: .infinity
        // frame would make every label greedy inside an HStack.
        #if os(watchOS)
        let alignsInsideHostedFrame = false
        #else
        let alignsInsideHostedFrame = true
        #endif

        // `.fixedSize(horizontal: false, vertical: true)` is the key for WRAPPING
        // a filled or preferred-width label: the NSHostingView computes its
        // intrinsic height at the Text's one-line ideal width BEFORE the
        // equal-width constraint pins it wider, so a long subtitle truncated to
        // a single line. fixedSize(vertical:) forces the Text to take its natural
        // multi-line height for the proposed width, so it wraps and grows instead
        // of truncating. Harmless on single-line labels.
        if let pmlw = overrides.preferredMaxLayoutWidth {
            // Explicit width → SwiftUI computes the correct WRAPPED height at
            // this width, so the NSHostingView reports multi-line height to
            // the NSStackView and the next stacked element no longer overlaps
            // a wrapped label. (A bare `.frame(maxWidth:.infinity)` reports the
            // single-line ideal height at fitting-size time — the root of the
            // long-standing fill-label-height under-reservation bug.) Takes
            // precedence over fillHorizontal. The outer flexible frame keeps
            // the ideal width at `pmlw` and places the fixed-width text at the
            // leading edge (per textAlignment) when the renderer pins the label
            // wider, e.g. a fill_horizontal label in a Fill-aligned VStack.
            content = AnyView(
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: CGFloat(pmlw.doubleValue), alignment: frameAlign)
            )
            if alignsInsideHostedFrame {
                content = AnyView(content.frame(maxWidth: .infinity, alignment: frameAlign))
            }
        } else if overrides.fillHorizontal?.boolValue == true {
            content = AnyView(
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlign)
            )
        } else if alignsInsideHostedFrame {
            // A flexible frame keeps the Text's ideal width (the label still
            // hugs its text) and aligns it inside a wider column, such as the
            // exact `frame(width:)` CommonModifiers applies for a label whose
            // minimum_width == maximum_width.
            content = AnyView(content.frame(maxWidth: .infinity, alignment: frameAlign))
        }

        // A minimum height is the label's line box, never a cap: a wrapped label
        // grows past it to show every line instead of drawing them over the next
        // view.
        content = CommonModifiers.apply(content, overrides: overrides, growsPastMinimumHeight: true)
        if overrides.selectable?.boolValue == true {
            content = AnyView(content.textSelection(.enabled))
        }
        if overrides.trailingLinkText != nil {
            let linkToken = overrides.trailingLinkToken?.uint64Value ?? 0
            content = AnyView(content.environment(\.openURL, OpenURLAction { url in
                if linkToken != 0 {
                    CallbackBridge.fire(token: linkToken, value: 0)
                    return .handled
                }
                return url == Self.handlerOnlyLinkURL ? .discarded : .systemAction
            }))
        }
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

// Natural line height of the font the label facade resolves, so a requested
// line height can be expressed as SwiftUI `lineSpacing` (the extra space
// between lines). Mirrors the font selection in `APSKLabelHost.body`.
enum APSKLabelLineMetrics {
    static func naturalLineHeight(for overrides: LabelOverrides) -> CGFloat {
        let explicitSize = (overrides.fontSize?.doubleValue).flatMap { $0 > 0 ? CGFloat($0) : nil }
        #if os(macOS)
        let font: NSFont
        if let family = overrides.fontFamily, family != "system", !family.isEmpty {
            let size = explicitSize ?? 17.0
            if family == "monospace" {
                font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            } else {
                font = NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
            }
        } else if let size = explicitSize {
            font = NSFont.systemFont(ofSize: size, weight: platformWeight(overrides.fontWeight))
        } else {
            font = NSFont.preferredFont(forTextStyle: .body)
        }
        return NSLayoutManager().defaultLineHeight(for: font)
        #elseif canImport(UIKit)
        let font: UIFont
        if let family = overrides.fontFamily, family != "system", !family.isEmpty {
            let size = explicitSize ?? 17.0
            if family == "monospace" {
                font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            } else {
                font = UIFont(name: family, size: size) ?? UIFont.systemFont(ofSize: size)
            }
        } else if let size = explicitSize {
            font = UIFont.systemFont(ofSize: size, weight: platformWeight(overrides.fontWeight))
        } else {
            font = UIFont.preferredFont(forTextStyle: .body)
        }
        return font.lineHeight
        #else
        return explicitSize.map { $0 * 1.2 } ?? 20.0
        #endif
    }

    #if os(macOS)
    private static func platformWeight(_ rawValue: NSNumber?) -> NSFont.Weight {
        weightTable[rawValue?.intValue ?? 0].map { NSFont.Weight(rawValue: $0) } ?? .regular
    }
    #elseif canImport(UIKit)
    private static func platformWeight(_ rawValue: NSNumber?) -> UIFont.Weight {
        weightTable[rawValue?.intValue ?? 0].map { UIFont.Weight(rawValue: $0) } ?? .regular
    }
    #endif

    // SwiftUI weight rawValues (see `Font.Weight(rawValue:)` above) to the
    // platform font weight scale.
    private static let weightTable: [Int: CGFloat] = [
        -3: -0.8, -2: -0.6, -1: -0.4, 0: 0.0, 1: 0.23, 2: 0.3, 3: 0.4, 4: 0.56, 5: 0.62,
    ]
}
