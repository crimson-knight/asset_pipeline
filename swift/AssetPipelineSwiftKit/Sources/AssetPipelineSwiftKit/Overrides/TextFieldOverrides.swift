// TextFieldOverrides — per-TextField overrides above ViewOverrides.
//
// Fields:
//   secureEntry  : NSNumber bool. nil = SwiftUI default (`TextField`,
//                  not `SecureField`).
//   keyboardType : "default" | "email" | "number" | "phone" | "url" — only
//                  consumed on iOS via `.keyboardType(_:)`. nil = default.

import Foundation

@objc(APSKTextFieldOverrides)
public class TextFieldOverrides: ViewOverrides {
    @objc public var secureEntry: NSNumber? = nil
    @objc public var keyboardType: String? = nil
    // Semantic AutoFill identity/address/contact hint.
    @objc public var contentType: String? = nil
    // Return-key label and optional keyboard accessory action.
    @objc public var submitLabel: String? = nil
    @objc public var keyboardToolbar: NSNumber? = nil
    // Move between mounted UIKit text inputs without asking Crystal to rebuild
    // the form. Opt-in preserves callback-driven navigation for older clients.
    @objc public var nativeFocusNavigation: NSNumber? = nil
    // Text assistance preferences.
    @objc public var autocapitalization: String? = nil
    @objc public var autocorrectionDisabled: NSNumber? = nil
    // Font: point size, raw Font.Weight intValue, custom family / PostScript
    // name. nil = SwiftUI default. A real family ("Alegreya-Medium", …) renders
    // via `.font(.custom(name, size:))`; the consumer registers the TTF first
    // (apsk_register_font). Mirrors LabelOverrides / ButtonOverrides.
    @objc public var fontSize: NSNumber? = nil
    @objc public var fontWeight: NSNumber? = nil
    @objc public var fontFamily: String? = nil
    // Visual chrome: nil/"roundedborder" = boxed default; "underline" = bottom-
    // rule only (transparent fill); "plain" = no chrome.
    @objc public var borderStyle: String? = nil
    // Placeholder tint. nil = the kit's contrast-safe default (label @ 50%
    // opacity). When set (Crystal `text_field.placeholder_color = ...`), the
    // PromptOverlayField uses this color literally so a brand placeholder
    // (e.g. #bec2c2 over a photo hero) renders exactly.
    @objc public var placeholderColor: APSKPlatformColor? = nil
    // Submit callback token (Crystal `text_field.on_submit`). When non-nil, the
    // facade attaches `.onSubmit` so bare Return fires the string-valued
    // trampoline with the current text — the Enter-to-send contract. nil = no
    // submit handler (Return does nothing, the prior behavior).
    @objc public var submitToken: NSNumber? = nil
    // Previous-field callback token for the native iOS keyboard accessory.
    // nil/0 disables the upward navigation button for the first field.
    @objc public var previousToken: NSNumber? = nil

    @objc public override init() { super.init() }
}
