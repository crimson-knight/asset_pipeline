module Voyager
  # Voyager — Sign In screen.
  #
  # Email TextField + SecureField + Sign In button. On Sign In tap,
  # coord.push(Route.new(:todos)) advances to the Todos screen. Email
  # validation is a basic regex (display-only — the demo doesn't reject
  # bad emails to keep the happy-path navigable in 3 clicks).
  module SignInScreen
    extend self

    SLUG = "voyager-sign-in"

    def build(state : State, coord : UI::NavigationCoordinator) : UI::View
      # Phase 6.10 Rem 4 (Item 2D/2E + Item 3) — device-aware sizing.
      #
      # The OUTER root uses `root_fill = true` so iOS / macOS renderers
      # size the screen to the live device bounds via
      # `UI::DesignTokens::DeviceMetrics.current`. The inner fields still
      # carry an explicit `content_width` cap so SwiftUI TextFields /
      # SecureFields don't collapse to their placeholder intrinsic width
      # inside the UIHostingController + UIStackView mix.
      #
      # Item 3 (off-screen Sign-in button frame) fix: the Sign-in button
      # had `minimum_width = max_width = 340.0` on a centered VStack
      # whose own width was ALSO pinned to 340. With the root pinned to
      # 340 and aligned center inside a wider iPhone 17 Pro safe-area
      # bounds (402pt content), the negative x-origin came from the
      # SwiftUI ScrollView default-priority width-hint constraint
      # racing the inner 340pt pin. Removing the outer width pin (now
      # `root_fill`) lets UIKit auto-layout center the button cleanly
      # within the live device width, and the inner cap stays at 340pt
      # so the field column doesn't stretch to the edge on iPad.
      metrics = UI::DesignTokens::DeviceMetrics.current
      # Cap form-field width to 340pt on compact devices (iPhone
      # portrait) and 400pt on regular (iPad portrait, landscape
      # macOS). Authors override per-screen via the field's
      # `minimum_width` / `maximum_width` props.
      content_width = metrics.compact_horizontal? ? 340.0 : 400.0

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
      fields.alignment = UI::Alignment::Leading
      fields.minimum_width = content_width
      fields.maximum_width = content_width

      email = UI::TextField.new(placeholder: "Email")
      email.text = state.current_user
      email.accessibility_label = "Email address"
      email.test_id = "voyager-sign-in-email"
      email.keyboard_type = UI::KeyboardType::EmailAddress
      email.minimum_width = content_width
      email.maximum_width = content_width
      email.on_change = ->(value : String) { state.current_user = value }

      password = UI::SecureField.new(placeholder: "Password")
      password.accessibility_label = "Password"
      password.test_id = "voyager-sign-in-password"
      password.minimum_width = content_width
      password.maximum_width = content_width

      fields << email.as(UI::View)
      fields << password.as(UI::View)

      submit = UI::Button.new("Sign in", style: UI::ButtonStyle::Prominent)
      # accessibility_label matches the visible title so XCUITest / VoiceOver
      # users can find the button by what they see/hear without disambiguation.
      submit.accessibility_label = "Sign in"
      submit.test_id = "voyager-sign-in-submit"
      submit.minimum_width = content_width
      submit.maximum_width = content_width
      # The coordinator captures itself in the closure — push moves
      # us from :sign_in → :todos, firing on_change, which the host
      # subscribes to (see web/static_site.cr + macos/host.cr +
      # ios/bridge.cr) to rebuild the visible root.
      submit.on_tap = -> {
        coord.push(UI::NavigationCoordinator::Route.new(:todos))
      }

      root << wordmark.as(UI::View)
      root << subtitle.as(UI::View)
      root << fields.as(UI::View)
      root << submit.as(UI::View)

      root.as(UI::View)
    end
  end
end
