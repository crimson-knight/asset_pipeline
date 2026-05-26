# Thin horizontal or vertical separator line between content.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Divider — Thin horizontal or vertical separator line between content.
  class Divider < View
    # Color value.
    property color : Color = Color.new(r: 0.8, g: 0.8, b: 0.8)
    # Numeric value (pt unless otherwise noted).
    property thickness : Float64 = 1.0
    # Layout orientation (e.g. `:horizontal`, `:vertical`).
    property orientation : Symbol = :horizontal # :horizontal, :vertical

    def initialize(@orientation : Symbol = :horizontal)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:separator`.
    def default_accessibility_role : Symbol?
      :separator
    end
  end
end
