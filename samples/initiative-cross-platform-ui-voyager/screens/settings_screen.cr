module Voyager
  # Voyager — Settings screen.
  #
  # Phase 8D.1: migrated to `UI::Screen` subclass. Hide-completed toggle
  # dispatches `:toggle_filter` (SettingsController flips
  # `Voyager.state.hide_completed` and returns Rerender). Back link
  # dispatches `:back` (Pop).
  class SettingsScreen < UI::Screen
    SLUG = "voyager-settings"

    def build(context : UI::ScreenContext) : UI::View
      # Phase D Track 2 — whole-composition adapt via DeviceMetrics#responsive
      # (width + spacing + padding + title type), matching sign-in/welcome/todos.
      metrics = UI::DesignTokens::DeviceMetrics.current

      state = Voyager.state

      pad_h = metrics.responsive(compact: 20.0, regular: 28.0)
      pad_v = metrics.responsive_vertical(compact: 16.0, regular: 32.0)
      # Adaptive column width (shared helper): clamps to the device so the settings
      # controls reflow onto the watch instead of overflowing its ~176pt screen.
      content_width = metrics.adaptive_content_width(compact: 340.0, regular: 480.0, horizontal_padding: pad_h)
      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 10.0, regular: 18.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager settings screen"
      root.test_id = "voyager-settings-root"

      title = UI::Label.new("Settings")
      title.font = UI::Font.new(size: metrics.responsive(compact: 26.0, regular: 30.0), weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.maximum_width = content_width

      explainer = UI::Label.new("Hide completed todos from the main list.")
      explainer.font = UI::Font.new(size: 14.0, weight: :regular)
      explainer.text_color_role = UI::LabelRole::Secondary
      explainer.maximum_width = content_width

      # Component Gallery — the "show me the library" catalog. A native
      # showcase of the asset_pipeline UI widgets. Surfaced prominently
      # (above the toggle) because demonstrating the component library is
      # the primary purpose of the Voyager sample.
      gallery_btn = UI::Button.new("Component Gallery", style: UI::ButtonStyle::Prominent)
      gallery_btn.accessibility_label = "Open the component gallery"
      gallery_btn.test_id = "voyager-settings-component-gallery"
      gallery_btn.minimum_width = content_width
      gallery_btn.maximum_width = content_width
      gallery_btn.on_tap = -> { Voyager.dispatch(:open_component_gallery) }

      # Daily Check-in — the control-rich coaching surface (Slider/Stepper/Toggle),
      # reachable here so it's a live part of the navigable app, not just a captured demo.
      check_in_btn = UI::Button.new("Daily check-in")
      check_in_btn.role = :secondary
      check_in_btn.accessibility_label = "Open daily check-in"
      check_in_btn.test_id = "voyager-settings-check-in"
      check_in_btn.minimum_width = content_width
      check_in_btn.maximum_width = content_width
      check_in_btn.on_tap = -> { Voyager.dispatch(:open_check_in) }

      hide_toggle = UI::Toggle.new(label: "Hide completed", is_on: state.hide_completed)
      hide_toggle.accessibility_label = "Hide completed todos"
      hide_toggle.test_id = "voyager-settings-hide-completed"
      hide_toggle.minimum_width = content_width
      hide_toggle.maximum_width = content_width
      # Phase 8D.1 — :toggle_filter routes to SettingsController#toggle_filter
      # which flips Voyager.state.hide_completed and returns Rerender.
      hide_toggle.on_change = ->(_value : Bool) { Voyager.dispatch(:toggle_filter) }

      # Voice section — the agent's spoken-reply speed (UI::Speech rate), persisted
      # via UI::Preferences and used by every speak call. Demonstrates a Slider +
      # Button driving a real system capability + persistence, cohesively.
      voice_title = UI::Label.new("Voice")
      voice_title.font = UI::Font.new(size: 16.0, weight: :semibold)
      voice_title.text_color_role = UI::LabelRole::Secondary
      voice_title.maximum_width = content_width

      rate_pct = (state.speech_rate * 100).round.to_i
      rate_readout = UI::Label.new("Voice speed: #{rate_pct}%")
      rate_readout.font = UI::Font.new(size: 14.0, weight: :regular)
      rate_readout.text_color_role = UI::LabelRole::Secondary
      rate_readout.test_id = "voyager-settings-speech-rate-readout"
      rate_readout.maximum_width = content_width

      rate_slider = UI::Slider.new(0.35, 0.65, state.speech_rate)
      rate_slider.accessibility_label = "Voice speed"
      rate_slider.test_id = "voyager-settings-speech-rate"
      rate_slider.minimum_width = content_width
      rate_slider.maximum_width = content_width
      # Transport the rate as an INTEGER percent, not a Float string: both
      # Float#to_s (here) and String#to_f? (the controller) route through Crystal's
      # FastFloat tables, which are NOT initialized under the iOS/watchOS Swift
      # @main embedding (class-init gap) → SIGSEGV. Int#to_s / String#to_i? are safe.
      rate_slider.on_change = ->(v : Float64) { Voyager.dispatch(:set_speech_rate, {"value" => (v * 100).round.to_i.to_s}) }

      preview_btn = UI::Button.new("Preview voice")
      preview_btn.role = :secondary
      preview_btn.accessibility_label = "Preview voice"
      preview_btn.test_id = "voyager-settings-preview-voice"
      preview_btn.minimum_width = content_width
      preview_btn.maximum_width = content_width
      preview_btn.on_tap = -> { Voyager.dispatch(:preview_voice) }

      back = UI::Button.new("Back to todos")
      back.role = :secondary
      back.accessibility_label = "Back to todos"
      back.test_id = "voyager-settings-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }

      # Phase 10D-refocus — Developer / Internals section. The Phase 10
      # exerciser hub is a developer tool (intent-dispatch litmus,
      # capability resolver harness, AX metadata browser, environment
      # reactivity sandbox, new-widgets isolation surface) — not part
      # of the end-user flow. Per the refocus brief it lives under a
      # dedicated section header in Settings so the surfacing is
      # clearly "internal."
      dev_section_title = UI::Label.new("Developer / Internals")
      dev_section_title.font = UI::Font.new(size: 16.0, weight: :semibold)
      dev_section_title.text_color_role = UI::LabelRole::Secondary
      dev_section_title.test_id = "voyager-settings-developer-section"
      dev_section_title.maximum_width = content_width

      dev_section_explainer = UI::Label.new(
        "Internal demos for the Phase 10 intent + widget surface. " \
        "Not part of the user-facing app."
      )
      dev_section_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      dev_section_explainer.text_color_role = UI::LabelRole::Tertiary
      dev_section_explainer.maximum_width = content_width

      phase_10_btn = UI::Button.new("Phase 10 Developer Tools", style: UI::ButtonStyle::Bordered)
      phase_10_btn.accessibility_label = "Open Phase 10 developer tools"
      phase_10_btn.test_id = "voyager-settings-phase-10"
      phase_10_btn.minimum_width = content_width
      phase_10_btn.maximum_width = content_width
      phase_10_btn.on_tap = -> { Voyager.dispatch(:open_phase_10_hub) }

      root << title.as(UI::View)
      root << explainer.as(UI::View)
      root << gallery_btn.as(UI::View)
      root << check_in_btn.as(UI::View)
      root << hide_toggle.as(UI::View)
      root << voice_title.as(UI::View)
      root << rate_readout.as(UI::View)
      root << rate_slider.as(UI::View)
      root << preview_btn.as(UI::View)
      root << back.as(UI::View)
      root << dev_section_title.as(UI::View)
      root << dev_section_explainer.as(UI::View)
      root << phase_10_btn.as(UI::View)

      root.as(UI::View)
    end
  end
end
