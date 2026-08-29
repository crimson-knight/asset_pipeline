# Filled or stroked rectangular geometric primitive.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Rectangle — Filled or stroked rectangular geometric primitive.
  class Rectangle < View
    # Solid fill color for the shape body.
    property fill_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
    # Stroke / outline color for the shape.
    property stroke_color : Color? = nil
    # Stroke / outline width in pt.
    property stroke_width : Float64 = 0.0
    # Intrinsic width in pt.
    property width : Float64 = 100.0
    # Intrinsic height in pt.
    property height : Float64 = 50.0

    def initialize(@width : Float64 = 100.0, @height : Float64 = 50.0)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
