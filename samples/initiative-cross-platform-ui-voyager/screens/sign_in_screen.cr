module Voyager
  # Voyager — Sign In screen.
  #
  # Phase 8D.1: migrated from a module-level class with
  # `build(state, coord)` to a `UI::Screen` subclass with
  # `build(ctx : UI::ScreenContext) : UI::View`. User-intent callbacks
  # route through `Voyager.dispatch(:action_name, action_params)` per
  # the brief's action-ref convention; the controller layer
  # (`SignInController`) interprets the actions and returns
  # `UI::ActionResult` subtypes that the dispatcher translates into
  # coordinator operations.
  class SignInScreen < UI::Screen
    SLUG = "voyager-sign-in"

    def build(context : UI::ScreenContext) : UI::View
      # Phase 6.10 Rem 4 (Item 2D/2E + Item 3) — device-aware sizing.
      # See screens/sign_in.cr pre-8D.1 history for the layout rationale
      # (root_fill + content_width cap + safe-area aware padding).
      metrics = UI::DesignTokens::DeviceMetrics.current
      # Phase B/C — the form is a resizable "readable column" via UI::Fluid:
      # it tracks available width between min and max instead of a hard pin, so
      # the screen reflows on window resize / size-class change. `ideal` keeps the
      # prior per-size-class width as the comfortable default.
      ideal_width = metrics.compact_horizontal? ? 340.0 : 400.0
      form_fluid = UI::Fluid.px(280, ideal_width, 420)

      state = Voyager.state

      root = UI::VStack.new(spacing: 24.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Center
      root.padding = UI::EdgeInsets.new(
        top: 48.0 + metrics.safe_area_top_pt,
        trailing: 32.0 + metrics.safe_area_trailing_pt,
        bottom: 48.0 + metrics.safe_area_bottom_pt,
        leading: 32.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager sign in screen"
      root.test_id = "voyager-sign-in-root"

      wordmark = UI::Label.new("Voyager")
      wordmark.font = UI::Font.new(size: 34.0, weight: :bold)
      wordmark.text_color_role = UI::LabelRole::Primary
      wordmark.text_alignment = UI::Alignment::Center
      wordmark.accessibility_label = "Voyager brand wordmark"

      subtitle = UI::Label.new("Sign in to manage your todos")
      subtitle.font = UI::Font.new(size: 15.0, weight: :regular)
      subtitle.text_color_role = UI::LabelRole::Secondary
      subtitle.text_alignment = UI::Alignment::Center

      fields = UI::VStack.new(spacing: 12.0)
      # Fill so the controls stretch to the fluid form column's resolved width.
      fields.alignment = UI::Alignment::Fill

      # Phase 8D.1 — the renderer's wire-time TextField hook
      # (UI::FormStateRendererHook.wrap_text_handler) reads
      # UI::FormState.current and writes typed values into the
      # dispatcher's per-mount FormState under the `name` key. Brief
      # contract: SignInController#submit reads `ctx.form_state["email"]`
      # and `ctx.form_state["password"]`.
      email = UI::TextField.new(placeholder: "Email", name: "email")
      email.text = state.current_user
      email.accessibility_label = "Email address"
      email.test_id = "voyager-sign-in-email"
      email.keyboard_type = UI::KeyboardType::EmailAddress
      # No width pin — fills the fluid form column via the Fill alignment above.
      # NOTE on `state.current_user`: this is a UX-courtesy mirror so the
      # pre-populated email survives a re-render. The authoritative store
      # for the dispatched submit is FormState (renderer-wired). We keep
      # the side-write into state for the same UX as pre-8D.1.
      email.on_change = ->(value : String) { state.current_user = value }

      password = UI::SecureField.new(placeholder: "Password", name: "password")
      password.accessibility_label = "Password"
      password.test_id = "voyager-sign-in-password"

      fields << email.as(UI::View)
      fields << password.as(UI::View)

      submit = UI::Button.new("Sign in", style: UI::ButtonStyle::Prominent)
      submit.accessibility_label = "Sign in"
      submit.test_id = "voyager-sign-in-submit"
      # Phase 8D.1 — Symbol action ref `:submit` routes to
      # SignInController#submit per the brief's action-ref convention.
      submit.on_tap = -> { Voyager.dispatch(:submit) }

      # Fluid form column: a resizable, centered readable column. fluid_width on
      # the CONTAINER maps to the renderer's min>=/max<= constraint pins (leaf
      # facades don't honor fluid_width); Fill alignment stretches the fields +
      # submit to the column's resolved width. root stays Center, so the column
      # is centered in the window and reflows between 280 and 420pt.
      form = UI::VStack.new(spacing: 16.0)
      form.alignment = UI::Alignment::Fill
      form.fluid_width = form_fluid
      form.test_id = "voyager-sign-in-form"
      form << fields.as(UI::View)
      form << submit.as(UI::View)

      root << wordmark.as(UI::View)
      root << subtitle.as(UI::View)
      root << form.as(UI::View)

      root.as(UI::View)
    end
  end
end
