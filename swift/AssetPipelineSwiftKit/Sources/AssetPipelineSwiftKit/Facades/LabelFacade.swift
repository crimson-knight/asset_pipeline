// LabelFacade — SwiftUI Text(_:) bridge.
//
// Default (empty LabelOverrides): system body font, `.primary` foreground
// (Apple-tracking light/dark), `.leading` alignment, unlimited line wrap.
// Overrides surface only via the ViewOverrides cascade or the
// LabelOverrides knobs (semantic role, alignment, line cap).

import SwiftUI
import Foundation

@objc(APSKLabelFacade)
public class LabelFacade: NSObject {
    @objc public static func makeLabel(
        text: String,
        overrides: LabelOverrides
    ) -> APSKPlatformView {
        var content: AnyView = AnyView(Text(text))

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
            break // nil → SwiftUI default (.primary, already implicit).
        }

        switch overrides.textAlignment {
        case "leading":   content = AnyView(content.multilineTextAlignment(.leading))
        case "center":    content = AnyView(content.multilineTextAlignment(.center))
        case "trailing":  content = AnyView(content.multilineTextAlignment(.trailing))
        default: break
        }

        if let n = overrides.numberOfLines, n.intValue > 0 {
            content = AnyView(content.lineLimit(n.intValue))
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(content)
    }
}
