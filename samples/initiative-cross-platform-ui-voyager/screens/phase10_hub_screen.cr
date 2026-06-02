module Voyager
  # Phase 10D — exerciser hub screen.
  #
  # Lists the 5 Phase 10 exerciser routes as buttons that dispatch
  # Navigate(:route_id) to the controller. Reachable from the Settings
  # screen via a "Phase 10 Exerciser" entry, and via `/phase-10` on the
  # static-site web build.
  class Phase10HubScreen < UI::Screen
    SLUG = "voyager-phase-10-hub"

    def build(context : UI::ScreenContext) : UI::View
      # Phase D Track 2 — whole-composition adapt via DeviceMetrics#responsive.
      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.responsive(compact: 340.0, regular: 480.0)

      pad_h = metrics.responsive(compact: 20.0, regular: 28.0)
      pad_v = metrics.responsive(compact: 24.0, regular: 32.0)
      root = UI::VStack.new(spacing: metrics.responsive(compact: 12.0, regular: 16.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Phase 10 developer tools hub"
      root.test_id = "phase-10-hub-root"

      title = UI::Label.new("Phase 10 Developer Tools")
      title.font = UI::Font.new(size: metrics.responsive(compact: 26.0, regular: 30.0), weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.maximum_width = content_width

      subtitle = UI::Label.new(
        "Internal verification surface for the Phase 10 intent + widget APIs. " \
        "Not part of the end-user todo flow — reachable from Settings → " \
        "Developer / Internals."
      )
      subtitle.font = UI::Font.new(size: 14.0, weight: :regular)
      subtitle.text_color_role = UI::LabelRole::Secondary
      subtitle.maximum_width = content_width

      root << title.as(UI::View)
      root << subtitle.as(UI::View)

      [
        {label: "Intent Resolver (:swipe_actions)", action: :open_phase_10_intent_resolver, test_id: "phase-10-hub-link-intent-resolver"},
        {label: "Class C Dispatch", action: :open_phase_10_class_c_dispatch, test_id: "phase-10-hub-link-class-c-dispatch"},
        {label: "AX Metadata + Keyboard Shortcut", action: :open_phase_10_ax_metadata, test_id: "phase-10-hub-link-ax-metadata"},
        {label: "Environment Reactivity", action: :open_phase_10_environment, test_id: "phase-10-hub-link-environment"},
        {label: "New Widgets (FullScreenCover, Inspector, Toolbar*)", action: :open_phase_10_new_widgets, test_id: "phase-10-hub-link-new-widgets"},
      ].each do |entry|
        btn = UI::Button.new(entry[:label], style: UI::ButtonStyle::Prominent)
        btn.accessibility_label = entry[:label]
        btn.test_id = entry[:test_id]
        btn.minimum_width = content_width
        btn.maximum_width = content_width
        action_ref = entry[:action]
        btn.on_tap = -> { Voyager.dispatch(action_ref) }
        root << btn.as(UI::View)
      end

      back = UI::Button.new("Back")
      back.role = :secondary
      back.accessibility_label = "Back"
      back.test_id = "phase-10-hub-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
