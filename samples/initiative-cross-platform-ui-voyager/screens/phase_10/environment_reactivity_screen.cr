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

      header = UI::Label.new(
        "reduce_motion: #{env.reduce_motion}\n" \
        "color_scheme: #{env.color_scheme}\n" \
        "dynamic_type_size: #{env.dynamic_type_size}\n" \
        "increase_contrast: #{env.increase_contrast}\n" \
        "accessibility_enabled: #{env.accessibility_enabled}"
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
      effective = UI::Animation.duration_seconds_with_environment(env, 4.0)
      duration_label = UI::Label.new(
        "Snackbar base duration: 4.0s\n" \
        "Effective with this Environment: #{effective}s\n" \
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
