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

    var body: some View {
        var content: AnyView = AnyView(Text(state.text))

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

        content = CommonModifiers.apply(content, overrides: overrides)
        return content
    }
}
