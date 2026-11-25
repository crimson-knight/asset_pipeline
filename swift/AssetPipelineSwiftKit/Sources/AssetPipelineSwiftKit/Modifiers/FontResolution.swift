// FontResolution — one answer to "which SwiftUI Font does this
// `UI::Font` (family, size, weight) draw with?", shared by the Label and
// Button facades so the two widgets resolve a family the same way.
//
// Families:
//   nil, "", "system" → the system face at the requested size and weight.
//   "monospace"       → the system monospaced face (SF Mono) at the
//                       requested size and weight.
//   any other name    → that registered face (a PostScript name such as
//                       "CourierPrime-Bold" or a family name such as
//                       "Michroma"), at the requested size, carrying the
//                       requested weight when one was set. When the name is
//                       not loadable the resolver reports it once through
//                       APSKFontDiagnostics and draws the system face at the
//                       requested size and weight instead.
//
// Size: the explicit size, else SwiftUI's body size (17pt).
// `scale` lets a caller apply Dynamic Type scaling to the point size.

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum FontResolution {
    static let systemFamily = "system"
    static let monospaceFamily = "monospace"
    static let bodyPointSize: Double = 17.0

    /// The SwiftUI font for the given overrides, or nil when the family is
    /// the system face and no size was set. In that case the caller keeps
    /// SwiftUI's own body font (and its text-style scaling) and applies a
    /// set weight with `.fontWeight(_:)` (see `weightOnly`).
    static func font(
        family: String?,
        size: NSNumber?,
        weight: NSNumber?,
        scale: (Double) -> CGFloat = { CGFloat($0) }
    ) -> Font? {
        let explicitSize = (size?.doubleValue).flatMap { $0 > 0 ? $0 : nil }
        let explicitWeight = weight.flatMap { fontWeight(rawValue: $0.intValue) }
        let requestedFamily = (family?.isEmpty == false) ? family! : systemFamily

        if requestedFamily == systemFamily && explicitSize == nil {
            return nil
        }

        let pointSize = scale(explicitSize ?? bodyPointSize)
        let resolvedWeight = explicitWeight ?? .regular

        switch requestedFamily {
        case systemFamily:
            return .system(size: pointSize, weight: resolvedWeight)
        case monospaceFamily:
            return .system(size: pointSize, weight: resolvedWeight, design: .monospaced)
        default:
            guard isLoadable(requestedFamily) else {
                APSKFontDiagnostics.reportMissingFamily(requestedFamily)
                return .system(size: pointSize, weight: resolvedWeight)
            }
            let custom = Font.custom(requestedFamily, size: pointSize)
            if let w = explicitWeight {
                return custom.weight(w)
            }
            return custom
        }
    }

    /// The weight to apply with `.fontWeight(_:)` when `font(...)` returned
    /// nil: the system family, no size, and an explicit weight.
    static func weightOnly(family: String?, size: NSNumber?, weight: NSNumber?) -> Font.Weight? {
        let requestedFamily = (family?.isEmpty == false) ? family! : systemFamily
        guard requestedFamily == systemFamily else { return nil }
        guard (size?.doubleValue).flatMap({ $0 > 0 ? $0 : nil }) == nil else { return nil }
        return weight.flatMap { fontWeight(rawValue: $0.intValue) }
    }

    /// True when the platform can load a face by this name.
    /// `Font.custom` never fails on an unknown name (it silently draws the
    /// system face), so the platform font class is asked first.
    static func isLoadable(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: name, size: 12.0) != nil
        #else
        if NSFont(name: name, size: 12.0) != nil { return true }
        // A family name such as "Courier Prime" is not always accepted by
        // NSFont(name:); ask the font manager for the family's members.
        return NSFontManager.shared.availableMembers(ofFontFamily: name)?.isEmpty == false
        #endif
    }

    /// SwiftUI `Font.Weight` for the integer the Crystal populator sends
    /// (`Populator.swiftui_font_weight_rawvalue`): ultraLight = -3 …
    /// regular = 0 … black = 5.
    static func fontWeight(rawValue: Int) -> Font.Weight? {
        switch rawValue {
        case -3: return .ultraLight
        case -2: return .thin
        case -1: return .light
        case 0: return .regular
        case 1: return .medium
        case 2: return .semibold
        case 3: return .bold
        case 4: return .heavy
        case 5: return .black
        default: return nil
        }
    }
}
