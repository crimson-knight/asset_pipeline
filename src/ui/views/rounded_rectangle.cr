# Rectangular primitive with configurable corner radius.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # RoundedRectangle — Rectangular primitive with configurable corner radius.
  class RoundedRectangle < View
    # Solid fill color for the shape body.
    property fill_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
    # Stroke / outline color for the shape.
    property stroke_color : Color? = nil
    # Stroke / outline width in pt.
    property stroke_width : Float64 = 0.0
    property corner_style : Symbol = :continuous # :continuous, :circular
    # Numeric value (pt unless otherwise noted).
    property corner_radius : Float64
    # Intrinsic width in pt.
    property width : Float64 = 100.0
    # Intrinsic height in pt.
    property height : Float64 = 50.0

    def initialize(@corner_radius : Float64 = 8.0, @width : Float64 = 100.0, @height : Float64 = 50.0)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
