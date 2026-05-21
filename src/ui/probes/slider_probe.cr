require "./probe_store"

module UI::Probes
  # SliderProbe — Phase 3 rubric BX4.
  #
  # Backs the `phase-03-slider-value-probe` slug. The Slider's
  # `on_change` writes the latest Float64 into `last_value`; the
  # adjacent Label reads `formatted` so the rendered text matches what
  # XCUITest reads via `staticTexts[...]`.
  module SliderProbe
    @@last_value : Float64 = 0.0

    def self.last_value : Float64
      @@last_value
    end

    def self.set(value : Float64) : Nil
      @@last_value = value
      ProbeStore.instance.set("slider-probe-value", formatted)
    end

    def self.reset : Nil
      @@last_value = 0.0
      ProbeStore.instance.set("slider-probe-value", "0.00")
    end

    def self.formatted : String
      sprintf("%.2f", @@last_value)
    end

    def self.current_text : String
      formatted
    end
  end
end
