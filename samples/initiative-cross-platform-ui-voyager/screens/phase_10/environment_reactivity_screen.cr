module Voyager
  # Phase 10D exerciser — Phase 10B.2c `UI::Environment` reactivity proof.
  #
  # Reads the per-render `ctx.environment` and displays the current
  # state of the three accessibility-driven flags:
  #
  #   * `reduce_motion`         — visible in the header text and in the
  #                                 Snackbar's effective duration.
  #   * `color_scheme`          — `:light` / `:dark` / `:high_contrast`.
  #   * `dynamic_type_size`     — symbolic Apple-style scale.
  #
  # The Snackbar at the bottom of the screen has a base duration of 4
  # seconds; when `reduce_motion` is on the effective duration collapses
  # to 0 seconds (per `UI::Animation.duration_seconds_with_environment`
  # — the canonical reactivity contract). Toggle Reduce Motion in
  # Settings → Accessibility → Motion to see the duration text change.
  class EnvironmentReactivityScreen < UI::Screen
    SLUG = "voyager-phase-10-environment"

    def build(context : UI::ScreenContext) : UI::View
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 340.0 : 480.0

      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 24.0 + metrics.safe_area_top_pt,
        trailing: 20.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 20.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Phase 10 — environment reactivity exerciser"
      root.test_id = "phase-10-environment-root"

      title = UI::Label.new("UI::Environment reactivity")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      env = context.environment

      # iOS class-init gap caveat: Symbol#to_s / Bool#to_s walk
      # class-var-backed tables that may not be primed on the iOS
      # embedding even with Crystal::Once.init. We project each value
      # through an explicit case to a literal String constant so the
      # interpolation never SIGSEGVs at Symbol#to_s.
      reduce_motion_s = env.reduce_motion ? "true" : "false"
      increase_contrast_s = env.increase_contrast ? "true" : "false"
      accessibility_enabled_s = env.accessibility_enabled ? "true" : "false"
      color_scheme_s = case env.color_scheme
                       when :light          then "light"
                       when :dark           then "dark"
                       when :high_contrast  then "high_contrast"
                       else                      "unknown"
                       end
      dynamic_type_s = case env.dynamic_type_size
                       when :xsmall   then "xsmall"
                       when :small    then "small"
                       when :medium   then "medium"
                       when :large    then "large"
                       when :xlarge   then "xlarge"
                       when :xxlarge  then "xxlarge"
                       when :xxxlarge then "xxxlarge"
                       when :ax1      then "ax1"
                       when :ax2      then "ax2"
                       when :ax3      then "ax3"
                       when :ax4      then "ax4"
                       when :ax5      then "ax5"
                       else                "unknown"
                       end

      header = UI::Label.new(
        "reduce_motion: " + reduce_motion_s + "\n" \
        "color_scheme: " + color_scheme_s + "\n" \
        "dynamic_type_size: " + dynamic_type_s + "\n" \
        "increase_contrast: " + increase_contrast_s + "\n" \
        "accessibility_enabled: " + accessibility_enabled_s
      )
      header.font = UI::Font.new(size: 13.0, weight: :semibold)
      header.text_color_role = UI::LabelRole::Primary
      header.test_id = "phase-10-environment-header"

      # The Snackbar's effective_duration helper consults
      # `UI::Animation.duration_seconds_with_environment` — when
      # reduce_motion is on the duration collapses to 0.0 (the
      # animation is killed). We display the helper's output so the
      # tester can verify the contract by toggling the Simulator's
      # Reduce Motion accessibility setting.
      # Float#to_s also walks an iOS class-init-skipped table —
      # render the effective duration via a tiny tri-state because
      # the two values we care about ARE the meaningful ones.
      effective = UI::Animation.duration_seconds_with_environment(env, 4.0)
      effective_s = (effective == 0.0) ? "0.0" : "4.0"
      duration_label = UI::Label.new(
        "Snackbar base duration: 4.0s\n" \
        "Effective with this Environment: " + effective_s + "s\n" \
        "(0.0s means motion was reduced)"
      )
      duration_label.font = UI::Font.new(size: 12.0, weight: :regular)
      duration_label.text_color_role = UI::LabelRole::Secondary
      duration_label.test_id = "phase-10-environment-duration"

      instructions = UI::Label.new(
        "How to flip Reduce Motion in the Simulator:\n" \
        "Settings → Accessibility → Motion → Reduce Motion ON.\n" \
        "Return here; the values above should reflect the change after the next render."
      )
      instructions.font = UI::Font.new(size: 12.0, weight: :regular)
      instructions.text_color_role = UI::LabelRole::Tertiary

      # A Snackbar sample. Static (no auto-dismiss runtime path on this
      # exerciser screen) — its purpose here is to make the duration
      # contract visible via the `effective_duration` getter that
      # consults env.
      snackbar = UI::Snackbar.new("This Snackbar honors env.reduce_motion")
      snackbar.duration = 4.0
      snackbar.is_presented = true
      snackbar.accessibility_label = "Phase 10 environment snackbar"
      snackbar.test_id = "phase-10-environment-snackbar"

      back = UI::Button.new("Back to Phase 10 hub")
      back.role = :secondary
      back.accessibility_label = "Back to Phase 10 hub"
      back.test_id = "phase-10-environment-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }

      root << title.as(UI::View)
      root << header.as(UI::View)
      root << duration_label.as(UI::View)
      root << instructions.as(UI::View)
      root << snackbar.as(UI::View)
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
