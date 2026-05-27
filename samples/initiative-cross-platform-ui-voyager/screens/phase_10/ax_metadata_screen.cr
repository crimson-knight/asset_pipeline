module Voyager
  # Phase 10D exerciser — Phase 10B.2a / 10B.2b AX metadata + keyboard
  # shortcut proof.
  #
  # Each widget on this screen demonstrates one of the new AX properties
  # added in Phase 10B.2:
  #
  #   * `accessibility_hint` / `accessibility_value` on a Label
  #   * `accessibility_actions` array on a Button (VoiceOver rotor)
  #   * `keyboard_shortcut` on a Button (external keyboard)
  #   * `accessibility_traits = [:not_enabled]` on a TextField
  #
  # The visible label text explains what each widget demonstrates so a
  # hand-tester can pair a widget with the property under test. Tap-able
  # widgets store a marker in `Phase10ExerciserState.last_action` and
  # trip a Rerender so the tester can see the callback fire.
  class AxMetadataScreen < UI::Screen
    SLUG = "voyager-phase-10-ax-metadata"

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
      root.accessibility_label = "Phase 10 — AX metadata exerciser"
      root.test_id = "phase-10-ax-metadata-root"

      title = UI::Label.new("AX Metadata + Keyboard Shortcuts")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      last_action = UI::Label.new(
        "Last action: #{Phase10ExerciserState.last_action}"
      )
      last_action.font = UI::Font.new(size: 13.0, weight: :semibold)
      last_action.text_color_role = UI::LabelRole::Primary
      last_action.test_id = "phase-10-ax-metadata-last-action"

      root << title.as(UI::View)
      root << last_action.as(UI::View)

      # ---- accessibility_hint + accessibility_value on a Label ----
      hint_explainer = UI::Label.new(
        "Label with accessibility_hint and accessibility_value:\nVoiceOver announces label, value, then hint."
      )
      hint_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      hint_explainer.text_color_role = UI::LabelRole::Secondary

      hint_label = UI::Label.new("Counter")
      hint_label.font = UI::Font.new(size: 18.0, weight: :semibold)
      hint_label.text_color_role = UI::LabelRole::Primary
      hint_label.accessibility_label = "Counter"
      hint_label.accessibility_hint = "This is a hint"
      hint_label.accessibility_value = "42"
      hint_label.test_id = "phase-10-ax-hint-label"

      root << hint_explainer.as(UI::View)
      root << hint_label.as(UI::View)

      # ---- accessibility_actions on a Button (VoiceOver rotor) ----
      ax_actions_explainer = UI::Label.new(
        "Button with accessibility_actions = [Refresh]:\nVoiceOver rotor → Actions → Refresh."
      )
      ax_actions_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      ax_actions_explainer.text_color_role = UI::LabelRole::Secondary

      ax_actions_btn = UI::Button.new("Reload list", style: UI::ButtonStyle::Prominent)
      ax_actions_btn.accessibility_label = "Reload list"
      ax_actions_btn.test_id = "phase-10-ax-actions-button"
      ax_actions_btn.minimum_width = content_width
      ax_actions_btn.maximum_width = content_width
      ax_actions_btn.accessibility_actions = [
        UI::AccessibilityAction.new("Refresh") {
          Phase10ExerciserState.last_action = "AX rotor Refresh fired"
          Voyager.dispatch(:phase_10_ax_action)
        },
      ]
      ax_actions_btn.on_tap = -> {
        Phase10ExerciserState.last_action = "Tap on Reload list"
        Voyager.dispatch(:phase_10_ax_action)
      }

      root << ax_actions_explainer.as(UI::View)
      root << ax_actions_btn.as(UI::View)

      # ---- keyboard_shortcut on a Button (external keyboard) ----
      kbd_explainer = UI::Label.new(
        "Button with keyboard_shortcut = Cmd+S:\nConnect an external keyboard and press Cmd+S."
      )
      kbd_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      kbd_explainer.text_color_role = UI::LabelRole::Secondary

      kbd_btn = UI::Button.new("Save (Cmd+S)", style: UI::ButtonStyle::Prominent)
      kbd_btn.accessibility_label = "Save"
      kbd_btn.test_id = "phase-10-ax-kbd-button"
      kbd_btn.minimum_width = content_width
      kbd_btn.maximum_width = content_width
      kbd_btn.keyboard_shortcut = UI::KeyboardShortcut.new("S", modifiers: [:command])
      kbd_btn.on_tap = -> {
        Phase10ExerciserState.last_action = "Save (kbd Cmd+S) fired"
        Voyager.dispatch(:phase_10_ax_action)
      }

      root << kbd_explainer.as(UI::View)
      root << kbd_btn.as(UI::View)

      # ---- accessibility_traits = [:not_enabled] on a TextField ----
      traits_explainer = UI::Label.new(
        "TextField with accessibility_traits = [:not_enabled]:\nVoiceOver announces 'dimmed' / 'disabled'."
      )
      traits_explainer.font = UI::Font.new(size: 12.0, weight: :regular)
      traits_explainer.text_color_role = UI::LabelRole::Secondary

      disabled_field = UI::TextField.new(placeholder: "Disabled — read only", name: "ax_traits_demo")
      disabled_field.text = "Read-only via AX trait"
      disabled_field.accessibility_label = "Disabled demo field"
      disabled_field.accessibility_traits = [:not_enabled]
      disabled_field.test_id = "phase-10-ax-traits-field"
      disabled_field.minimum_width = content_width
      disabled_field.maximum_width = content_width

      root << traits_explainer.as(UI::View)
      root << disabled_field.as(UI::View)

      back = UI::Button.new("Back to Phase 10 hub")
      back.role = :secondary
      back.accessibility_label = "Back to Phase 10 hub"
      back.test_id = "phase-10-ax-metadata-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
