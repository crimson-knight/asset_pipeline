module Voyager
  # Minimal state for the ComboBox Probe — the captured value.
  module ComboProbeState
    @@captured : String? = nil

    def self.captured : String
      @@captured ||= "Combo: (none)"
    end

    def self.captured=(value : String) : String
      @@captured = value
    end
  end

  # ComboBox Probe — a tiny VStack + readout Label + wired ComboBox. Used
  # to verify the ComboBox renders + its on_change is wired IN ISOLATION
  # (the full Component Gallery is an iOS showcase whose other widgets lack
  # tested macOS renderer paths, so it can't render on the macOS host).
  # on_change stores into ComboProbeState.captured without rerendering.
  class ComboProbeScreen < UI::Screen
    SLUG = "voyager-combo-probe"

    def build(context : UI::ScreenContext) : UI::View
      context.active_screen_class = self.class

      root = UI::VStack.new(spacing: 16.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(top: 32.0, trailing: 24.0, bottom: 24.0, leading: 24.0)
      root.accessibility_label = "Combo probe"
      root.test_id = "voyager-combo-root"

      title = UI::Label.new("ComboBox Probe")
      title.font = UI::Font.new(size: 22.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.test_id = "voyager-combo-title"
      root << title.as(UI::View)

      readout = UI::Label.new(ComboProbeState.captured)
      readout.font = UI::Font.new(size: 16.0, weight: :semibold)
      readout.text_color_role = UI::LabelRole::Primary
      readout.test_id = "voyager-combo-readout"
      root << readout.as(UI::View)

      combo = UI::ComboBox.new(
        value: "",
        options: ["Apple", "Banana", "Cherry"],
        placeholder: "Fruit",
        width: 280.0,
      )
      combo.accessibility_label = "Combo probe field"
      combo.test_id = "voyager-combo-field"
      combo.on_change = ->(v : String) { ComboProbeState.captured = "Combo: #{v}"; nil }
      root << combo.as(UI::View)

      reveal = UI::Button.new("Reveal")
      reveal.role = :secondary
      reveal.accessibility_label = "Reveal"
      reveal.test_id = "voyager-combo-reveal"
      reveal.on_tap = -> { Voyager.dispatch(:combo_reveal) }
      root << reveal.as(UI::View)

      root.as(UI::View)
    end
  end
end
