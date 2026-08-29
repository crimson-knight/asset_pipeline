module Voyager
  # Minimal state for the Reconcile Probe screen — a controlled reactive
  # text field. iOS class-init-gap discipline: nilable class var + lazy
  # accessor (no initializer side effects).
  module ReconcileProbeState
    @@text : String? = nil

    def self.text : String
      @@text ||= ""
    end

    def self.text=(value : String) : String
      @@text = value
    end
  end

  # Reconcile Probe — the smallest screen that exercises the in-place
  # reconciler end to end. A controlled TextField whose on_change
  # dispatches a Rerender on EVERY keystroke, plus an echo Label bound to
  # the same state. The tree is deliberately tiny and uses ONLY
  # reconciler-covered node kinds (VStack, Label, TextField, Button) so
  # the in-place reconcile succeeds for the whole tree — letting the
  # focused field's UITextField survive each rerender (keyboard focus
  # preserved) while the echo Label updates in place.
  #
  # Launched directly by GalleryTextInputTests via VOYAGER_ROOT_SLUG.
  class ReconcileProbeScreen < UI::Screen
    SLUG = "voyager-reconcile-probe"

    def build(context : UI::ScreenContext) : UI::View
      context.active_screen_class = self.class

      metrics = UI::DesignTokens::DeviceMetrics.current
      width = metrics.compact_horizontal? ? 340.0 : 420.0

      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 32.0 + metrics.safe_area_top_pt,
        trailing: 20.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 20.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Reconcile probe"
      root.test_id = "voyager-reconcile-root"

      title = UI::Label.new("Reconcile Probe")
      title.font = UI::Font.new(size: 24.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.test_id = "voyager-reconcile-title"
      root << title.as(UI::View)

      # Echo Label — updated IN PLACE by the reconciler on every keystroke.
      # No accessibility_label, so the test reads its text via .label.
      echo = UI::Label.new("Echo: #{ReconcileProbeState.text}")
      echo.font = UI::Font.new(size: 16.0, weight: :semibold)
      echo.text_color_role = UI::LabelRole::Primary
      echo.test_id = "voyager-reconcile-echo"
      root << echo.as(UI::View)

      # Controlled reactive field: dispatches a Rerender per keystroke and
      # echoes its value back into `text` on rebuild. Focus must survive
      # the rerender via the in-place reconcile.
      field = UI::TextField.new(placeholder: "Type here")
      field.text = ReconcileProbeState.text
      field.accessibility_label = "Reconcile field"
      field.test_id = "voyager-reconcile-field"
      field.minimum_width = width
      field.maximum_width = width
      field.on_change = ->(v : String) { Voyager.dispatch(:probe_text, {"text" => v}); nil }
      root << field.as(UI::View)

      back = UI::Button.new("Back")
      back.role = :secondary
      back.accessibility_label = "Back"
      back.test_id = "voyager-reconcile-back"
      back.minimum_width = width
      back.maximum_width = width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end
  end
end
