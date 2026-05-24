# Phase 8 spike — Sign In screen as a UI::Screen subclass.
#
# Spike findings so far:
#   1. UI::VStack.new doesn't take a block. Use `var = VStack.new(...)` +
#      `var << child`.
#   2. UI::TextField.new takes `placeholder:`, not `initial:`. Pre-populate
#      a field via `tf.text = value` setter. Phase 8A should consider
#      adding `initial:` kwarg to TextField/SecureField constructors so
#      form re-display after failed submit is ergonomic.
class SignInScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    email_value = context.params["email"]? || ""

    root = UI::VStack.new(spacing: 16.0)
    root << UI::Label.new("Phase 8 Amber Spike — Sign In")

    if msg = context.flash_data["error"]?
      root << UI::Label.new("⚠ #{msg}")
    elsif msg = context.flash_data["notice"]?
      root << UI::Label.new("✓ #{msg}")
    end

    fields = UI::VStack.new(spacing: 12.0)

    email_field = UI::TextField.new(placeholder: "you@example.com")
    email_field.text = email_value
    fields << email_field

    password_field = UI::SecureField.new(placeholder: "Password")
    fields << password_field

    fields << UI::Button.new("Sign in")

    root << fields
    root
  end
end
