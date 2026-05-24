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
      # Phase 6.10 Rem 4 (Item 2D/2E) — device-aware sizing. Outer
      # uses root_fill; inner Toggle + Back button still pin to
      # content_width so HStack children inside the Toggle facade
      # receive a deterministic parent width on iOS.
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
      hide_toggle.minimum_width = content_width
      hide_toggle.maximum_width = content_width
      hide_toggle.on_change = ->(value : Bool) {
        state.hide_completed = value
      }

      back = UI::Button.new("Back to todos")
      back.role = :secondary
      back.accessibility_label = "Back to todos"
      back.test_id = "voyager-settings-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> {
        coord.pop
        nil
      }

      root << title.as(UI::View)
      root << explainer.as(UI::View)
      root << hide_toggle.as(UI::View)
      root << back.as(UI::View)

      # Phase 6.10 Rem 3 (Item 3): framework default in VoyagerHost
      # wraps the root in a UIScrollView when content overflows; the
      # screen does not need explicit UI::ScrollView wrapping for the
      # iPhone 17 portrait happy-path. Leaving the root as a VStack so
      # the AppKit and UIKit renderers both pin content_width=340
      # without an extra scroll-view layer interfering with the inner
      # stack's auto-layout.
      root.as(UI::View)
    end
  end
end
