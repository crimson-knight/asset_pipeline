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
// Override behavior:
//   - `style = "prominent"` → `.buttonStyle(.borderedProminent)`
//   - `style = "tinted"`    → `.buttonStyle(.bordered).tint(.accentColor)`
//   - `style = "bordered"`  → `.buttonStyle(.bordered)`
//   - `style = "borderless"` → `.buttonStyle(.borderless)`
//   - `style = nil` or "automatic" → SwiftUI auto-picks (HIG-correct default).
//   - `role = "destructive"` → red emphasis via SwiftUI `ButtonRole.destructive`.
//   - `role = "cancel"`      → `.semibold` font weight per HIG.
//   - `disabled = true`      → `.disabled(true)`.
//   - `symbolName`           → leading SF Symbol via SwiftUI `Label`.
//   - All `ViewOverrides` fields are applied last via `CommonModifiers.apply`.

import SwiftUI
import Foundation

@objc(APSKButtonFacade)
public class ButtonFacade: NSObject {

    /// Build a SwiftUI `Button` hosted in a hosting controller.
    ///
    /// - Parameters:
    ///   - label: button title.
    ///   - overrides: nullable modifier carrier. Passing an empty
    ///                `ButtonOverrides()` yields full SwiftUI defaults.
    ///   - actionToken: opaque UInt64 produced by Crystal's
    ///                  `CallbackRegistry.register_action`. The Swift side
    ///                  invokes `ap_swiftkit_invoke_action(token, 0.0)` on
    ///                  tap. `0` means "no action wired."
    @objc public static func makeButton(
        label: String,
        overrides: ButtonOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        // Pick the SwiftUI button construction up front; we may switch
        // builders below to attach a destructive role or a symbol label.
        let action: () -> Void = {
            CallbackBridge.fire(token: actionToken, value: 0.0)
        }

        // Construct base view. Destructive role uses the SwiftUI role
        // initializer so the system applies its red emphasis treatment.
        let base: AnyView
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
            break // .automatic — SwiftUI picks per context.
        }

        // Per-widget overrides applied before common modifiers so the
        // common cascade can stack on top (e.g. user padding wraps the
        // button + its style modifier rather than landing inside the
        // SwiftUI button content).
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

        // Apply common (View-level) overrides last.
        content = CommonModifiers.apply(content, overrides: overrides)

        return HostingHelpers.host(content)
    }
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
