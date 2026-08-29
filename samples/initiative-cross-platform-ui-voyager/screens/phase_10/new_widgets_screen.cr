module Voyager
  # Phase 10D exerciser — Phase 10B.4 new-widget proof.
  #
  # Demonstrates the three Phase 10B.4 widgets:
  #
  #   * `UI::FullScreenCover`  — toggled by a button; the cover takes
  #                                the entire viewport.
  #   * `UI::Inspector`        — primary content beside an inspector pane.
  #   * `UI::ToolbarItemGroup` + `UI::ToolbarSpacer` — a clustered top
  #                                toolbar.
  #
  # State is read from `Phase10ExerciserState`:
  #
  #   * `full_screen_cover_presented` — flipped by the toggle button.
  #   * `inspector_presented`         — flipped by the inspector toggle.
  #
  # Toggles trip a Rerender so the screen rebuilds with the new
  # presentation flags. This is the explicit reactivity proof — the
  # FullScreenCover and Inspector classes hold `is_presented : Bool`
  # state and the screen re-reads it on each build.
  class NewWidgetsScreen < UI::Screen
    SLUG = "voyager-phase-10-new-widgets"

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
      root.accessibility_label = "Phase 10 — new widgets exerciser"
      root.test_id = "phase-10-new-widgets-root"

      title = UI::Label.new("New widgets (Phase 10B.4)")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      root << title.as(UI::View)

      # ---- ToolbarItemGroup + ToolbarSpacer ----
      tb_explainer = UI::Label.new(
        "ToolbarItemGroup + ToolbarSpacer at the top of the screen.\n" \
        "Items 1 + 2 are visually grouped; spacer pushes Item 3 trailing."
      )
      tb_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      tb_explainer.text_color_role = UI::LabelRole::Secondary

      group = UI::ToolbarItemGroup.new(label: "Formatting")
      group.add_item(id: "phase-10-tb-bold", label: "Bold") {
        Phase10ExerciserState.last_action = "Toolbar group Bold"
        Voyager.dispatch(:phase_10_widget_action)
      }
      group.add_item(id: "phase-10-tb-italic", label: "Italic") {
        Phase10ExerciserState.last_action = "Toolbar group Italic"
        Voyager.dispatch(:phase_10_widget_action)
      }
      group.accessibility_label = "Formatting cluster"
      group.test_id = "phase-10-toolbar-group"

      spacer = UI::ToolbarSpacer.new
      spacer.accessibility_label = "Toolbar spacer"
      spacer.test_id = "phase-10-toolbar-spacer"

      root << tb_explainer.as(UI::View)
      root << group.as(UI::View)
      root << spacer.as(UI::View)

      # ---- FullScreenCover toggle ----
      # Avoid Bool#to_s interpolation (iOS class-init gap; see
      # `[[crystal-ios-class-init-gap]]`). Project the Bool through an
      # explicit ternary to a literal String constant.
      fsc_state_s = Phase10ExerciserState.full_screen_cover_presented ? "true" : "false"
      fsc_explainer = UI::Label.new(
        "FullScreenCover — tap to flip is_presented. " \
        "Currently: " + fsc_state_s + "."
      )
      fsc_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      fsc_explainer.text_color_role = UI::LabelRole::Secondary

      fsc_toggle = UI::Button.new(
        Phase10ExerciserState.full_screen_cover_presented ? "Hide FullScreenCover" : "Show FullScreenCover",
        style: UI::ButtonStyle::Prominent,
      )
      fsc_toggle.accessibility_label = "Toggle full-screen cover"
      fsc_toggle.test_id = "phase-10-fsc-toggle"
      fsc_toggle.minimum_width = content_width
      fsc_toggle.maximum_width = content_width
      fsc_toggle.on_tap = -> {
        Phase10ExerciserState.full_screen_cover_presented = !Phase10ExerciserState.full_screen_cover_presented
        Voyager.dispatch(:phase_10_widget_action)
      }

      cover_content = UI::VStack.new(spacing: 12.0)
      cover_label = UI::Label.new("FullScreenCover content")
      cover_label.font = UI::Font.new(size: 22.0, weight: :bold)
      cover_label.text_color_role = UI::LabelRole::Primary
      cover_content << cover_label.as(UI::View)

      cover_dismiss = UI::Button.new("Dismiss cover", style: UI::ButtonStyle::Prominent)
      cover_dismiss.accessibility_label = "Dismiss full-screen cover"
      cover_dismiss.test_id = "phase-10-fsc-dismiss"
      cover_dismiss.on_tap = -> {
        Phase10ExerciserState.full_screen_cover_presented = false
        Voyager.dispatch(:phase_10_widget_action)
      }
      cover_content << cover_dismiss.as(UI::View)

      fsc = UI::FullScreenCover.new(cover_content.as(UI::View))
      fsc.is_presented = Phase10ExerciserState.full_screen_cover_presented
      fsc.accessibility_label = "Phase 10 demo full-screen cover"
      fsc.test_id = "phase-10-fsc"

      root << fsc_explainer.as(UI::View)
      root << fsc_toggle.as(UI::View)
      root << fsc.as(UI::View)

      # ---- Inspector ----
      ins_explainer = UI::Label.new(
        "Inspector — primary + side panel. " \
        "Toggle hides/shows the inspector pane via is_presented."
      )
      ins_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      ins_explainer.text_color_role = UI::LabelRole::Secondary

      ins_toggle = UI::Button.new(
        Phase10ExerciserState.inspector_presented ? "Hide Inspector" : "Show Inspector",
        style: UI::ButtonStyle::Prominent,
      )
      ins_toggle.accessibility_label = "Toggle inspector"
      ins_toggle.test_id = "phase-10-inspector-toggle"
      ins_toggle.minimum_width = content_width
      ins_toggle.maximum_width = content_width
      ins_toggle.on_tap = -> {
        Phase10ExerciserState.inspector_presented = !Phase10ExerciserState.inspector_presented
        Voyager.dispatch(:phase_10_widget_action)
      }

      primary = UI::VStack.new(spacing: 8.0)
      primary_label = UI::Label.new("Primary content")
      primary_label.font = UI::Font.new(size: 16.0, weight: :semibold)
      primary_label.text_color_role = UI::LabelRole::Primary
      primary << primary_label.as(UI::View)

      pane = UI::VStack.new(spacing: 8.0)
      pane_label = UI::Label.new("Inspector pane")
      pane_label.font = UI::Font.new(size: 16.0, weight: :semibold)
      pane_label.text_color_role = UI::LabelRole::Secondary
      pane << pane_label.as(UI::View)

      inspector = UI::Inspector.new(primary.as(UI::View), pane.as(UI::View))
      inspector.is_presented = Phase10ExerciserState.inspector_presented
      inspector.preferred_width = 240.0
      inspector.accessibility_label = "Phase 10 demo inspector"
      inspector.test_id = "phase-10-inspector"

      root << ins_explainer.as(UI::View)
      root << ins_toggle.as(UI::View)
      root << inspector.as(UI::View)

      # ---- back ----
      back = UI::Button.new("Back to Phase 10 hub")
      back.role = :secondary
      back.accessibility_label = "Back to Phase 10 hub"
      back.test_id = "phase-10-new-widgets-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
