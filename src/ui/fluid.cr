# Responsive sizing value (`Fluid(min, ideal, max)`) that translates to CSS
# `clamp(...)` on web and to platform-idiomatic size-class behavior on native.

module UI
  # Responsive sizing value. Translates to `clamp(min, ideal, max)` on web,
  # and to the platform's idiomatic size class behavior on Apple/Android
  # (handled by later phases).
  #
  # `min`, `ideal`, and `max` are CSS-compatible size strings (e.g., `"20rem"`,
  # `"60vw"`, `"480px"`). Use the `Fluid.px` / `Fluid.vw` constructors when you
  # have numeric pixel values rather than building strings by hand.
  record Fluid,
    min : String,
    ideal : String,
    max : String do
    # Construct from numeric pixel values. Pixels are emitted as `Npx`.
    def self.px(min : Number, ideal : Number, max : Number) : Fluid
      new(min: "#{min}px", ideal: "#{ideal}px", max: "#{max}px")
    end

    # Construct from a fluid `vw` ideal with px floor/ceiling.
    def self.vw(min_px : Number, ideal_vw : Number, max_px : Number) : Fluid
      new(min: "#{min_px}px", ideal: "#{ideal_vw}vw", max: "#{max_px}px")
    end

    # Render as a CSS `clamp()` expression.
    def to_css : String
      "clamp(#{min}, #{ideal}, #{max})"
    end

    # ------------------------------------------------------------------
    # Phase B — native resolution (additive). The native renderers feed these
    # into the EXISTING min/max width constraint pins (Auto-Layout then resolves
    # the actual width within [min, max] against available space — genuine
    # resize without replacing NSStackView/UIStackView sizing). See
    # docs/initiative-cross-platform-ui/architecture/foundational-output-and-layout-model.md
    # Principle 2.
    #
    # `px` and `rem` map to a fixed point count (1rem = 16px). Viewport-relative
    # units (`vw`/`vh`/`%`) have no fixed native value — they return nil, and the
    # native renderer relies on the min/max constraint range instead (an `ideal`
    # expressed in `vw` is exactly the "resize between min and max" case).
    # ------------------------------------------------------------------

    # Minimum width/height in points, or nil if `min` is not a fixed unit.
    def native_min_px : Float64?
      Fluid.parse_native_px(min)
    end

    # Maximum width/height in points, or nil if `max` is not a fixed unit.
    def native_max_px : Float64?
      Fluid.parse_native_px(max)
    end

    # Ideal width/height in points, or nil if `ideal` is not a fixed unit
    # (e.g. a `vw` ideal — native uses the min/max range in that case).
    def native_ideal_px : Float64?
      Fluid.parse_native_px(ideal)
    end

    # Parse a CSS length to native points. `px`/`rem` resolve; everything else
    # (vw/vh/%/calc/clamp/…) returns nil.
    def self.parse_native_px(value : String) : Float64?
      s = value.strip.downcase
      if s.ends_with?("px")
        s[0...-2].strip.to_f?
      elsif s.ends_with?("rem")
        s[0...-3].strip.to_f?.try { |v| v * 16.0 }
      else
        nil
      end
    end
  end
end
