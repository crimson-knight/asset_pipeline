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

    # Parse the Swift colour value-channel payload "r,g,b,a" (four sRGB
    # floats on 0.0..1.0, comma-separated, '.'-decimal) into a UI::Color.
    # Returns nil for a malformed payload so the renderer's on_change only
    # fires on a well-formed pick (mirrors the string trampoline's
    # silent-no-op-on-garbage policy). Channels are clamped to 0.0..1.0.
    def self.parse_rgba(payload : String) : Color?
      parts = payload.split(',')
      return nil unless parts.size == 4
      vals = parts.map(&.strip.to_f?)
      return nil if vals.any?(&.nil?)
      r, g, b, a = vals.map { |v| v.not_nil!.clamp(0.0, 1.0) }
      Color.new(r: r, g: g, b: b, a: a)
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
