# Pressed-state button used as a toggle (e.g. bold / italic toolbar buttons).
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # ToggleButton — Pressed-state button used as a toggle (e.g. bold / italic toolbar buttons).
  class ToggleButton < View
    # Caption / accessibility label rendered alongside the control.
    property label : String
    # Boolean toggle.
    property is_selected : Bool = false
    # Optional icon shown next to the title. Native: SF Symbol name; web: icon class or URL.
    property icon : String? = nil
    # Invoked when the toggle's `is_on` value flips.
    property on_toggle : Proc(Bool, Nil)? = nil

    def initialize(@label : String, @is_selected : Bool = false)
    end

    def initialize(@label : String, @is_selected : Bool = false, &block : Bool -> Nil)
      @on_toggle = block
    end

    # Flips the control's on / off state.
    def toggle
      @is_selected = !@is_selected
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:button`.
    def default_accessibility_role : Symbol?
      :button
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
