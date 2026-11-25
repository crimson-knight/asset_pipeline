# Gradient fill for a stack's background (`VStack#background_gradient`,
# `HStack#background_gradient`, `ZStack#background_gradient`).

module UI
  # A point in a view's unit square: (0, 0) is the top-leading corner and
  # (1, 1) the bottom-trailing corner, as in SwiftUI's UnitPoint.
  record UnitPoint, x : Float64, y : Float64 do
    TOP_LEADING     = new(0.0, 0.0)
    TOP             = new(0.5, 0.0)
    CENTER          = new(0.5, 0.5)
    BOTTOM          = new(0.5, 1.0)
    BOTTOM_TRAILING = new(1.0, 1.0)
  end

  # One color of a gradient at `location`, from 0.0 (where the gradient
  # starts) to 1.0 (where it ends). The color may be a
  # `UI::Color.dynamic(light:, dark:)`, which follows the appearance.
  record GradientStop, color : Color, location : Float64

  # Raised when a gradient is built with fewer than two stops.
  class GradientNeedsTwoStopsError < ArgumentError
  end

  # A linear or radial gradient drawn behind a stack's children.
  #
  # ```
  # sky = UI::BackgroundGradient.linear([
  #   UI::GradientStop.new(color: UI::Color.dynamic(light: dawn, dark: dusk), location: 0.0),
  #   UI::GradientStop.new(color: UI::Color.dynamic(light: noon, dark: night), location: 1.0),
  # ])
  # stack.background_gradient = sky
  # ```
  struct BackgroundGradient
    enum Kind
      Linear
      Radial
    end

    getter gradient_kind : Kind
    getter list_of_color_stops : Array(GradientStop)
    # Linear: where the first stop is drawn. Radial: the center.
    getter start_point : UnitPoint
    # Linear: where the last stop is drawn. Radial: `end_point - start_point`
    # is the horizontal and vertical radius, as fractions of the view's width
    # and height.
    getter end_point : UnitPoint

    def initialize(@gradient_kind : Kind, @list_of_color_stops : Array(GradientStop),
                   @start_point : UnitPoint, @end_point : UnitPoint)
      if @list_of_color_stops.size < 2
        raise GradientNeedsTwoStopsError.new("A gradient needs two or more color stops (got #{@list_of_color_stops.size})")
      end
    end

    # A gradient along the line `from` -> `to` (top to bottom by default).
    def self.linear(list_of_color_stops : Array(GradientStop),
                    from start_point : UnitPoint = UnitPoint::TOP,
                    to end_point : UnitPoint = UnitPoint::BOTTOM) : BackgroundGradient
      new(Kind::Linear, list_of_color_stops, start_point, end_point)
    end

    # A gradient in rings around `centered_at`. `radius_fraction` is the radius
    # of the last stop as a fraction of the view's width (horizontally) and
    # height (vertically), so 0.5 reaches the middle of each edge.
    def self.radial(list_of_color_stops : Array(GradientStop),
                    centered_at center : UnitPoint = UnitPoint::CENTER,
                    radius_fraction : Float64 = 0.5) : BackgroundGradient
      edge = UnitPoint.new(center.x + radius_fraction, center.y + radius_fraction)
      new(Kind::Radial, list_of_color_stops, center, edge)
    end

    def radial? : Bool
      gradient_kind.radial?
    end
  end

  # Adds a gradient background and a film-grain overlay to a stack.
  module PaintsBackgroundGradient
    # Gradient drawn behind the stack's children, over its `background`
    # color. Drawn on macOS.
    property background_gradient : BackgroundGradient? = nil

    # Opacity (0.0 to 1.0) of a static noise tile laid over the stack's
    # background, for a printed-paper grain. 0.0 draws no grain. Drawn on
    # macOS.
    property grain_opacity : Float64 = 0.0
  end
end
