# Increment / decrement stepper for adjusting a discrete numeric value.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Stepper — Increment / decrement stepper for adjusting a discrete numeric value.
  class Stepper < View
    # Current value of the control.
    property value : Float64 = 0.0
    # Minimum legal value (inclusive).
    property minimum : Float64 = 0.0
    # Maximum legal value (inclusive).
    property maximum : Float64 = 100.0
    # Increment / decrement amount applied per tick.
    property step_value : Float64 = 1.0
    # Caption / accessibility label rendered alongside the control.
    property label : String = ""
    # Whether the value wraps around at the min / max boundary.
    property wraps : Bool = false
    # Invoked when the user changes the control's value.
    property on_change : Proc(Float64, Nil)? = nil

    def initialize(@minimum : Float64 = 0.0, @maximum : Float64 = 100.0, @value : Float64 = 0.0)
    end

    def initialize(@minimum : Float64, @maximum : Float64, @value : Float64 = 0.0, &block : Float64 -> Nil)
      @on_change = block
    end

    # Increases the value by `step_value`, clamping or wrapping per `wraps`.
    def increment
      new_val = @value + @step_value
      if new_val > @maximum
        @value = @wraps ? @minimum : @maximum
      else
        @value = new_val
      end
    end

    # Decreases the value by `step_value`, clamping or wrapping per `wraps`.
    def decrement
      new_val = @value - @step_value
      if new_val < @minimum
        @value = @wraps ? @maximum : @minimum
      else
        @value = new_val
      end
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:spinbutton`.
    def default_accessibility_role : Symbol?
      :spinbutton
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
