// ButtonFacade — the SwiftUI Button bridge.
//
// Call site (Crystal): `LibSwiftKitBridge.make_button(label, overrides, token)`
// → C trampoline `apsk_make_button` → `APSKButtonFacade.makeButton`
//   (this file) → SwiftUI `Button` → `UIHostingController`/`NSHostingController`
// → raw `UIView`/`NSView` pointer handed back to Crystal.
//
// Default (empty `ButtonOverrides`) behavior on iOS 26 / macOS 26:
//   - System tint, system body font, default insets
//   - Built-in hover/press animations
//   - VoiceOver accessibility trait `.button`
//   - Dynamic Type support
//   - Dark / light appearance tracking
//   - Liquid Glass treatment for `.prominent` style on iOS 26+
//
// Phase 3 Remediation 4 (reactive overrides): three properties — background
// color, foreground color, corner radius — are routed through an
// `APSKButtonState` `@ObservedObject` so the Crystal renderer can mutate
// them at runtime (BX5 override-rerender-runtime). Style / role / disabled
// / symbol remain construction-time fixed: they affect Swift type identity
// of the underlying SwiftUI Button and changing them post-compose would
// require a full re-render anyway.

import SwiftUI
import Foundation

@objc(APSKButtonFacade)
public class ButtonFacade: NSObject {

    /// Static-construction entry point retained for back-compat.
    @objc public static func makeButton(
        label: String,
        overrides: ButtonOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        return makeReactiveButton(
            label: label, overrides: overrides,
            actionToken: actionToken, outState: nil
        )
    }

    /// Reactive-construction entry. `outState` receives a +1 retained
    /// pointer to an `APSKButtonState` that Crystal can later mutate via
    /// `apsk_button_set_background_color` etc.
    @objc public static func makeReactiveButton(
        label: String,
        overrides: ButtonOverrides,
        actionToken: UInt64,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        // Seed the reactive state from the construction-time ViewOverrides
        // fields. A nil entry means "leave SwiftUI default in force"; a
        // later Crystal-side mutation toggles the same field on the state.
        let state = APSKButtonState(
            backgroundColor: overrides.backgroundColor,
            foregroundColor: overrides.foregroundColor,
            cornerRadius: overrides.cornerRadius
        )

        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(state).toOpaque()
        }

        let body = APSKButtonHost(
            label: label,
            overrides: overrides,
            actionToken: actionToken,
            state: state
        )
        return HostingHelpers.host(body)
    }
}

private struct APSKButtonHost: View {
    let label: String
    let overrides: ButtonOverrides
    let actionToken: UInt64
    @ObservedObject var state: APSKButtonState

    var body: some View {
        let action: () -> Void = { [actionToken] in
            CallbackBridge.fire(token: actionToken, value: 0.0)
        }

        // Construct base view. Destructive role uses the SwiftUI role
        // initializer so the system applies its red emphasis treatment.
        var base: AnyView
        if overrides.role == "destructive" {
            if let symbol = overrides.symbolName {
                base = AnyView(
                    Button(role: .destructive, action: action) {
                        Label(label, systemImage: symbol)
                    }
                )
            } else {
                base = AnyView(
                    Button(role: .destructive, action: action) {
                        Text(label)
                    }
                )
            }
        } else if let symbol = overrides.symbolName {
            base = AnyView(
                Button(action: action) {
                    Label(label, systemImage: symbol)
                }
            )
        } else {
            base = AnyView(Button(label, action: action))
        }

        // Style cascade. SwiftUI layers system defaults (font, animation,
        // focus, dynamic type, dark mode) over whatever style we pick.
        var content: AnyView = base
        switch overrides.style {
        case "prominent":
            content = AnyView(content.buttonStyle(.borderedProminent))
        case "tinted":
            content = AnyView(content.buttonStyle(.bordered))
        case "bordered":
            content = AnyView(content.buttonStyle(.bordered))
        case "borderless":
            content = AnyView(content.buttonStyle(.borderless))
        default:
            break
        }

        if overrides.role == "cancel" {
            content = AnyView(content.fontWeight(.semibold))
        }
        if let weight = overrides.fontWeight {
            let resolved = Font.Weight(rawValue: weight.intValue) ?? .regular
            content = AnyView(content.fontWeight(resolved))
        }
        if let disabled = overrides.disabled, disabled.boolValue {
            content = AnyView(content.disabled(true))
        }

        // ----- Reactive (Remediation 4) override layer ---------------------
        //
        // Apply background / foreground / cornerRadius from the reactive
        // state. These three fields are explicitly NOT applied through
        // `CommonModifiers.apply` below (we shadow them on a per-render
        // override carrier so the static cascade leaves them alone). The
        // state was seeded from the construction-time ViewOverrides
        // equivalents in `makeReactiveButton`, so this stays the single
        // source of truth for those three properties.

        if let bg = state.backgroundColor {
            #if canImport(UIKit)
            content = AnyView(content.background(Color(uiColor: bg)))
            #elseif canImport(AppKit)
            content = AnyView(content.background(Color(nsColor: bg)))
            #endif
        }

        if let fg = state.foregroundColor {
            #if canImport(UIKit)
            content = AnyView(content.foregroundStyle(Color(uiColor: fg)))
            #elseif canImport(AppKit)
            content = AnyView(content.foregroundStyle(Color(nsColor: fg)))
            #endif
        }

        if let cr = state.cornerRadius {
            content = AnyView(
                content.clipShape(RoundedRectangle(cornerRadius: CGFloat(cr.doubleValue)))
            )
        }

        // Apply common (View-level) overrides last, excluding the three
        // reactive fields that the state layer above already handled.
        // We shadow them on a copy of the overrides so CommonModifiers
        // does not re-apply (which would either double-stack the
        // background / foreground or use a stale value after a runtime
        // mutation).
        let shadowed = ButtonOverrides()
        copyViewOverrides(from: overrides, to: shadowed, skipReactiveFields: true)
        shadowed.fontWeight = overrides.fontWeight
        shadowed.role = overrides.role
        shadowed.style = overrides.style
        shadowed.disabled = overrides.disabled
        shadowed.symbolName = overrides.symbolName
        content = CommonModifiers.apply(content, overrides: shadowed)
        return content
    }
}

/// Copy every `ViewOverrides` field from `src` to `dst`. When
/// `skipReactiveFields` is true, the three fields the reactive state
/// layer owns (`backgroundColor`, `foregroundColor`, `cornerRadius`)
/// are left at nil on `dst` so `CommonModifiers.apply` no-ops on them.
private func copyViewOverrides(
    from src: ViewOverrides,
    to dst: ViewOverrides,
    skipReactiveFields: Bool
) {
    if !skipReactiveFields {
        dst.backgroundColor = src.backgroundColor
        dst.foregroundColor = src.foregroundColor
        dst.cornerRadius = src.cornerRadius
    }
    dst.paddingTop = src.paddingTop
    dst.paddingLeading = src.paddingLeading
    dst.paddingBottom = src.paddingBottom
    dst.paddingTrailing = src.paddingTrailing
    dst.borderWidth = src.borderWidth
    dst.borderColor = src.borderColor
    dst.shadowRadius = src.shadowRadius
    dst.shadowColor = src.shadowColor
    dst.shadowOffsetX = src.shadowOffsetX
    dst.shadowOffsetY = src.shadowOffsetY
    dst.opacity = src.opacity
    dst.hidden = src.hidden
    dst.minWidth = src.minWidth
    dst.minHeight = src.minHeight
    dst.maxWidth = src.maxWidth
    dst.maxHeight = src.maxHeight
    dst.accessibilityIdentifier = src.accessibilityIdentifier
    dst.apskAccessibilityLabel = src.apskAccessibilityLabel
}

// SwiftUI's `Font.Weight` initializer below is a small extension that
// lets us reconstruct a weight from the `NSNumber` int rawValue Crystal
// passes through. The values match SwiftUI's `Font.Weight` static cases.
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
