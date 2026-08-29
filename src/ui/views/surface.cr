# Generic themed surface used as a background for other content.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Surface — Generic themed surface used as a background for other content.
  class Surface < View
    # Child view rendered inside this container.
    property content : View? = nil
    # Logical Z-depth used for shadow + material selection.
    property elevation : Float64 = 0.0
    # Numeric value (pt unless otherwise noted).
    property tonal_elevation : Float64 = 0.0
    # Bounding shape used to clip / mask the view.
    property shape : Symbol = :rectangle # :rectangle, :rounded, :circle

    def initialize(@content : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
