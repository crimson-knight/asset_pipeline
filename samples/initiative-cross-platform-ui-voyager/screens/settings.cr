module Voyager
  # Voyager — Settings screen.
  #
  # Single "Hide completed" Toggle. This is the make-or-break state
  # propagation litmus: toggle on, pop back to Todos, see the list +
  # chart immediately reflect.
  module SettingsScreen
    extend self

    SLUG = "voyager-settings"

    def build(state : State, coord : UI::NavigationCoordinator) : UI::View
      root = UI::VStack.new(spacing: 16.0)
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(top: 24.0, trailing: 20.0, bottom: 24.0, leading: 20.0)
      root.accessibility_label = "Voyager settings screen"
      root.test_id = "voyager-settings-root"

      title = UI::Label.new("Settings")
      title.font = UI::Font.new(size: 28.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary

      explainer = UI::Label.new("Hide completed todos from the main list.")
      explainer.font = UI::Font.new(size: 14.0, weight: :regular)
      explainer.text_color_role = UI::LabelRole::Secondary

      hide_toggle = UI::Toggle.new(label: "Hide completed", is_on: state.hide_completed)
      hide_toggle.accessibility_label = "Hide completed todos"
      hide_toggle.test_id = "voyager-settings-hide-completed"
      hide_toggle.on_change = ->(value : Bool) {
        state.hide_completed = value
      }

      back = UI::Button.new("Back to todos")
      back.role = :secondary
      back.accessibility_label = "Return to the todos list"
      back.test_id = "voyager-settings-back"
      back.on_tap = -> { coord.pop; nil }

      root << title.as(UI::View)
      root << explainer.as(UI::View)
      root << hide_toggle.as(UI::View)
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
