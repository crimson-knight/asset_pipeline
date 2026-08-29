module Voyager
  # Phase 10D exerciser — `UI::WidgetRoute.resolve` proof.
  #
  # Demonstrates the Phase 10B.0 Tier-2 resolver pipeline by asking the
  # registry for the platform-appropriate widget that backs the
  # `:swipe_actions` intent and rendering 3 sample rows with that
  # resolved class. On iOS / iPadOS / web_narrow this resolves to
  # `UI::SwipeActionRow`. On macOS / web_wide this resolves to
  # `UI::InlineActionRow`. On Android it resolves to
  # `UI::AndroidSwipeActionRow`.
  #
  # The header label spells out the resolved class name so the tester
  # can verify the right type was returned for the running platform.
  # The "Edit" / "Delete" / "Archive" actions wire `on_tap` callbacks
  # that mutate `Voyager::Phase10ExerciserState.last_action` and trip a
  # Rerender — making the action callback visible.
  #
  # iOS class-init gap notes:
  # * String interpolation `"#{...}"` walks class-var-backed tables
  #   that aren't primed on the iOS embedding even after
  #   `Crystal::Once.init` (see
  #   `[[crystal-ios-class-init-gap]]`). Every variable surface on
  #   this screen is converted into a literal String via explicit
  #   `case` branches; concatenation uses the `String#+(String)`
  #   path (which is class-var-clean) instead of interpolation.
  class IntentResolverScreen < UI::Screen
    SLUG = "voyager-phase-10-intent-resolver"

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
      root.accessibility_label = "Phase 10 intent resolver exerciser"
      root.test_id = "phase-10-intent-resolver-root"

      title = UI::Label.new("Intent Resolver (:swipe_actions)")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      # Resolve the platform-appropriate widget class via the Tier-2
      # registry. This is the canonical Phase 10B.0 call site —
      # screens never name `SwipeActionRow` directly.
      resolved_class = UI::WidgetRoute.resolve(:swipe_actions, context)

      # Project the resolved class object + platform Symbol into
      # literal String constants without interpolation.
      resolved_name = if resolved_class == UI::SwipeActionRow
                        "UI::SwipeActionRow"
                      elsif resolved_class == UI::InlineActionRow
                        "UI::InlineActionRow"
                      elsif resolved_class == UI::AndroidSwipeActionRow
                        "UI::AndroidSwipeActionRow"
                      else
                        "unknown"
                      end
      platform_name = case context.platform
                      when :ios        then "ios"
                      when :ipados     then "ipados"
                      when :macos      then "macos"
                      when :android    then "android"
                      when :web_wide   then "web_wide"
                      when :web_narrow then "web_narrow"
                      else                  "unknown"
                      end

      header = UI::Label.new(
        "This row came from UI::WidgetRoute.resolve(:swipe_actions, ctx)"
      )
      header.font = UI::Font.new(size: 13.0, weight: :regular)
      header.text_color_role = UI::LabelRole::Secondary
      header.test_id = "phase-10-intent-resolver-header"

      resolved_label = UI::Label.new("Resolved widget: " + resolved_name)
      resolved_label.font = UI::Font.new(size: 13.0, weight: :semibold)
      resolved_label.text_color_role = UI::LabelRole::Primary
      resolved_label.test_id = "phase-10-intent-resolver-resolved"

      platform_label = UI::Label.new("Platform: " + platform_name)
      platform_label.font = UI::Font.new(size: 13.0, weight: :regular)
      platform_label.text_color_role = UI::LabelRole::Secondary
      platform_label.test_id = "phase-10-intent-resolver-platform"

      last_action_label = UI::Label.new(
        "Last action: " + Phase10ExerciserState.last_action
      )
      last_action_label.font = UI::Font.new(size: 13.0, weight: :semibold)
      last_action_label.text_color_role = UI::LabelRole::Primary
      last_action_label.test_id = "phase-10-intent-resolver-last-action"

      back = UI::Button.new("Back to Phase 10 hub")
      back.role = :secondary
      back.accessibility_label = "Back to Phase 10 hub"
      back.test_id = "phase-10-intent-resolver-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }

      root << title.as(UI::View)
      root << header.as(UI::View)
      root << resolved_label.as(UI::View)
      root << platform_label.as(UI::View)
      root << last_action_label.as(UI::View)

      # Build 3 sample rows using the resolver-returned class.
      row_letters = ["A", "B", "C"]
      row_letters.each do |letter|
        row_label = UI::Label.new("Sample row " + letter)
        row_label.font = UI::Font.new(size: 16.0, weight: :semibold)
        row_label.text_color_role = UI::LabelRole::Primary

        content = UI::HStack.new(spacing: 12.0)
        content.alignment = UI::Alignment::Center
        content.padding = UI::EdgeInsets.new(top: 10.0, trailing: 12.0, bottom: 10.0, leading: 12.0)
        content << row_label.as(UI::View)

        captured = letter
        edit = UI::SwipeAction.new(
          "Edit",
          on_tap: -> {
            Phase10ExerciserState.last_action = "Edit on row " + captured
            Voyager.dispatch(:phase_10_intent_action)
          },
        )
        delete = UI::SwipeAction.new(
          "Delete",
          on_tap: -> {
            Phase10ExerciserState.last_action = "Delete on row " + captured
            Voyager.dispatch(:phase_10_intent_action)
          },
          role: :destructive,
        )
        archive = UI::SwipeAction.new(
          "Archive",
          on_tap: -> {
            Phase10ExerciserState.last_action = "Archive on row " + captured
            Voyager.dispatch(:phase_10_intent_action)
          },
        )
        actions = [edit, delete, archive]

        # Narrow `resolved_class` (statically `UI::View.class`) to one
        # of the three known concrete row types so we can call the
        # `.new(View)` constructor + `trailing_actions=`.
        row : UI::View
        if resolved_class == UI::SwipeActionRow
          r = UI::SwipeActionRow.new(content.as(UI::View))
          r.trailing_actions = actions
          r.minimum_width = content_width
          r.maximum_width = content_width
          row = r.as(UI::View)
        elsif resolved_class == UI::InlineActionRow
          r = UI::InlineActionRow.new(content.as(UI::View))
          r.trailing_actions = actions
          r.minimum_width = content_width
          r.maximum_width = content_width
          row = r.as(UI::View)
        elsif resolved_class == UI::AndroidSwipeActionRow
          r = UI::AndroidSwipeActionRow.new(content.as(UI::View))
          r.trailing_actions = actions
          r.minimum_width = content_width
          r.maximum_width = content_width
          row = r.as(UI::View)
        else
          fallback = UI::Label.new("Unknown resolved class for :swipe_actions")
          fallback.text_color_role = UI::LabelRole::Tertiary
          row = fallback.as(UI::View)
        end
        row.accessibility_label = "Intent row " + letter
        row.test_id = "phase-10-intent-row-" + letter

        root << row
      end

      root << back.as(UI::View)
      root.as(UI::View)
    end
  end
end
