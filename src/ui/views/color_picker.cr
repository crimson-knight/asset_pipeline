# Color selection control bridging to the native color picker on each platform.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # ColorPicker — Color selection control bridging to the native color picker on each platform.
  class ColorPicker < View
    # Color value.
    property selected_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
    # Invoked when the user changes the control's value.
    property on_change : Proc(Color, Nil)? = nil
    # Caption / accessibility label rendered alongside the control.
    property label : String = ""
    # Boolean toggle.
    property supports_alpha : Bool = false

    def initialize
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
