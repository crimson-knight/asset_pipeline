module Voyager
  # Voyager — Daily Check-in screen. A coaching-style check-in that exercises the
  # interactive CONTROL widgets — Slider (mood), Stepper (daily goal), Toggle (reminder)
  # — in one cohesive surface, rendered natively on macOS / iOS / watchOS from this single
  # Crystal `UI::Screen`. All controls are watch-supported facades; the screen adapts to
  # each canvas through the shared DeviceMetrics#adaptive_content_width helper (column
  # width clamps from a Mac window down to the watch). Controls are functional, not
  # decorative: each on_change dispatches a value-carrying action that mutates
  # Voyager.state and Rerenders (see CheckInController), and the readout labels reflect
  # the live state.
  class CheckInScreen < UI::Screen
    SLUG = "voyager-check-in"

    def build(context : UI::ScreenContext) : UI::View
      state = Voyager.state
      metrics = UI::DesignTokens::DeviceMetrics.current
      pad_h = metrics.responsive(compact: 20.0, regular: 28.0)
      pad_v = metrics.responsive_vertical(compact: 16.0, regular: 32.0)
      content_width = metrics.adaptive_content_width(compact: 340.0, regular: 460.0, horizontal_padding: pad_h)

      root = UI::VStack.new(spacing: metrics.responsive_vertical(compact: 10.0, regular: 16.0))
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: pad_v + metrics.safe_area_top_pt,
        trailing: pad_h + metrics.safe_area_trailing_pt,
        bottom: pad_v + metrics.safe_area_bottom_pt,
        leading: pad_h + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Voyager daily check-in"
      root.test_id = "voyager-check-in-root"

      title = UI::Label.new("Daily Check-in")
      title.font = UI::Font.new(size: metrics.responsive(compact: 26.0, regular: 30.0), weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.maximum_width = content_width
      root << title.as(UI::View)

      # Summary card — a live readout of the three control values (Card facade).
      summary = UI::Label.new(
        "Mood #{state.checkin_mood}/10 · Goal #{state.checkin_goal}/day · " \
        "Reminder #{state.checkin_reminder ? "on" : "off"}"
      )
      summary.text_color_role = UI::LabelRole::Secondary
      summary.minimum_width = content_width - 42.0
      summary.maximum_width = content_width - 42.0
      summary.preferred_max_layout_width = content_width - 42.0
      summary_card = UI::Card.new(summary.as(UI::View))
      summary_card.maximum_width = content_width
      summary_card.test_id = "voyager-check-in-summary"
      root << summary_card.as(UI::View)

      # Mood — Slider 0..10.
      mood_label = UI::Label.new("Mood: #{state.checkin_mood}")
      mood_label.maximum_width = content_width
      root << mood_label.as(UI::View)
      mood = UI::Slider.new(0.0, 10.0, state.checkin_mood.to_f)
      mood.accessibility_label = "Mood"
      mood.test_id = "voyager-check-in-mood"
      mood.minimum_width = content_width
      mood.maximum_width = content_width
      mood.on_change = ->(v : Float64) { Voyager.dispatch(:set_mood, {"value" => v.round.to_i.to_s}) }
      root << mood.as(UI::View)

      # Daily goal — Stepper 1..20.
      goal_label = UI::Label.new("Daily goal: #{state.checkin_goal} tasks")
      goal_label.maximum_width = content_width
      root << goal_label.as(UI::View)
      goal = UI::Stepper.new(1.0, 20.0, state.checkin_goal.to_f)
      goal.label = "Daily goal"
      goal.accessibility_label = "Daily goal"
      goal.test_id = "voyager-check-in-goal"
      goal.minimum_width = content_width
      goal.maximum_width = content_width
      goal.on_change = ->(v : Float64) { Voyager.dispatch(:set_goal, {"value" => v.round.to_i.to_s}) }
      root << goal.as(UI::View)

      # Reminder — Toggle.
      reminder = UI::Toggle.new("Remind me tomorrow", state.checkin_reminder)
      reminder.accessibility_label = "Remind me tomorrow"
      reminder.test_id = "voyager-check-in-reminder"
      reminder.minimum_width = content_width
      reminder.maximum_width = content_width
      reminder.on_change = ->(_v : Bool) { Voyager.dispatch(:toggle_reminder) }
      root << reminder.as(UI::View)

      root << UI::Spacer.new.as(UI::View)

      save = UI::Button.new("Save check-in", style: UI::ButtonStyle::Prominent)
      save.accessibility_label = "Save check-in"
      save.test_id = "voyager-check-in-save"
      save.minimum_width = content_width
      save.maximum_width = content_width
      save.on_tap = -> { Voyager.dispatch(:save_checkin) }
      root << save.as(UI::View)

      back = UI::Button.new("Back")
      back.role = :secondary
      back.accessibility_label = "Back"
      back.test_id = "voyager-check-in-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
