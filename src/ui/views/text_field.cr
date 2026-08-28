# Single-line plain-text input field.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Visual chrome for a text field.
  #   RoundedBorder — the default boxed `.roundedBorder` field.
  #   Underline     — a bottom-border-only field (no box) — the Expo onboarding
  #                   input style: a 1px rule under the text, transparent fill.
  #   Plain         — no chrome at all.
  enum TextFieldStyle
    RoundedBorder
    Underline
    Plain
  end

  # Semantic purpose of a text field. Native platforms use this for
  # password-manager/contact AutoFill; web renders the matching `autocomplete`
  # token. It is deliberately separate from `KeyboardType`: an email field,
  # for example, needs both an email keyboard and an email identity hint.
  enum TextContentType
    None
    Name
    FullStreetAddress
    StreetAddressLine1
    AddressCity
    AddressState
    PostalCode
    TelephoneNumber
    EmailAddress
  end

  # Label shown on the software keyboard's Return key. Number/phone keyboards
  # do not have a Return key on iOS, so `keyboard_toolbar = true` also exposes
  # the same action in a keyboard accessory toolbar.
  enum TextInputAction
    Default
    Next
    Done
    Send
    Go
    Search
    Continue
  end

  # Platform text-capitalization preference.
  enum TextAutocapitalization
    Default
    Never
    Words
    Sentences
    Characters
  end

  # An editable single-line text input field.
  #
  # Provides placeholder text, secure entry mode for passwords,
  # keyboard type hints, and a change callback.
  class TextField < View
    # Visual chrome (RoundedBorder default; Underline = bottom-rule only).
    property style : TextFieldStyle = TextFieldStyle::RoundedBorder

    # Current text value
    property text : String = ""

    # Placeholder text shown when empty
    property placeholder : String = ""

    # Name attribute for web POST submission. When non-nil and the
    # field renders into a `<form>` (UI::Form), the web renderer emits
    # `name="..."` so the browser includes this field in the form-encoded
    # body. Native renderers ignore this property — they collect field
    # values via FormState in Phase 8B/8C.
    property name : String? = nil

    # Font for the text field content
    property font : Font = Font.new

    # Text color
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)

    # Placeholder tint. `nil` (the default) keeps the kit's contrast-safe
    # placeholder (`label @ 50% opacity`, ≥ 3:1 in light + dark). Set it to
    # match a brand placeholder color (e.g. Expo's `#bec2c2` over a photo
    # hero) — the consumer owns the contrast trade-off when they override.
    property placeholder_color : Color? = nil

    # Whether input is obscured (password entry)
    property secure_entry : Bool = false

    # Keyboard type hint for platform input method
    property keyboard_type : KeyboardType = KeyboardType::Default

    # Semantic identity/contact/address hint used by platform AutoFill.
    property content_type : TextContentType = TextContentType::None

    # Software keyboard Return-key label.
    property submit_label : TextInputAction = TextInputAction::Default

    # Show an action above keyboards (notably phone/number pads) that do not
    # provide a Return key. The action invokes `on_submit`.
    property keyboard_toolbar : Bool = false

    # Capitalization and correction preferences. `nil` correction keeps the
    # platform default, while true/false explicitly disables/enables it.
    property autocapitalization : TextAutocapitalization = TextAutocapitalization::Default
    property autocorrection_disabled : Bool? = nil

    # Callback invoked when the text value changes.
    # Receives the new text string.
    property on_change : Proc(String, Nil)? = nil

    # Callback invoked when the user submits the field (bare Return / Enter).
    # Receives the current text. Mirrors SearchField#on_submit; on macOS/iOS the
    # facade attaches SwiftUI `.onSubmit`. nil = Return does nothing (the prior
    # behavior). This is the Enter-to-send primitive.
    property on_submit : Proc(String, Nil)? = nil

    # Construct a TextField. `text:` pre-populates the value (useful
    # when re-rendering a form after a failed submit). `name:` sets the
    # HTML form-input name for web POST submission.
    def initialize(@placeholder : String = "", *, @name : String? = nil, @text : String = "")
    end

    # Convenience constructor with a change handler block.
    def initialize(@placeholder : String = "", *, @name : String? = nil, @text : String = "", &block : String -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:text_field`.
    def default_accessibility_role : Symbol?
      :text_field
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
