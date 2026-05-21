require "./probe_store"

module UI::Probes
  # SliderProbe — Phase 3 rubric BX4.
  #
  # Backs the `phase-03-slider-value-probe` slug. The Slider's
  # `on_change` writes the latest Float64 into `last_value`; the
  # adjacent Label reads `formatted` so the rendered text matches what
  # XCUITest reads via `staticTexts[...]`.
  module SliderProbe
    # Use Float64? so callers can distinguish "no value yet" from "0.0".
    # Crystal Float64 default-initialisation is technically 0.0 but the
    # cross-platform load order has produced cases where the singleton's
    # class storage is read before any setter has run; on iOS this took
    # the Float printer (`Float::Printer::RyuPrintf`) down with a
    # KERN_INVALID_ADDRESS while formatting an uninitialised slot.
    # Treating the value as optional and supplying a safe formatter
    # closes the window without touching the BX4 hot path semantics.
    @@last_value : Float64? = 0.0

    def self.last_value : Float64
      @@last_value || 0.0
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
      v = @@last_value
      return "0.00" if v.nil?
      # Defensive: NaN / Infinity cannot be formatted by `%.2f` reliably on
      # every platform. Round-trip through a finite default rather than
      # ever passing such a Float to `sprintf`.
      return "0.00" unless v.finite?
      sprintf("%.2f", v)
    end

    def self.current_text : String
      formatted
    end
  end
end
