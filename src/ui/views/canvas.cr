# Low-level drawing surface backed by the native platform 2D drawing API.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  enum DrawCommand
    MoveTo
    LineTo
    Arc
    QuadCurveTo
    BezierCurveTo
    ClosePath
    Fill
    Stroke
    SetFillColor
    SetStrokeColor
    SetLineWidth
    BeginPath
  end

  record CanvasOp,
    command : DrawCommand,
    x : Float64 = 0.0,
    y : Float64 = 0.0,
    x2 : Float64 = 0.0,
    y2 : Float64 = 0.0,
    x3 : Float64 = 0.0,
    y3 : Float64 = 0.0,
    radius : Float64 = 0.0,
    start_angle : Float64 = 0.0,
    end_angle : Float64 = 0.0,
    color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)

  # Canvas — Low-level drawing surface backed by the native platform 2D drawing API.
  class Canvas < View
    # Intrinsic width in pt.
    property width : Float64 = 300.0
    # Intrinsic height in pt.
    property height : Float64 = 150.0
    # Drawing / canvas operations recorded for replay.
    property operations : Array(CanvasOp) = [] of CanvasOp

    def initialize(@width : Float64 = 300.0, @height : Float64 = 150.0)
    end

    # Moves the cursor to `(x, y)` without drawing.
    def move_to(x : Float64, y : Float64)
      @operations << CanvasOp.new(command: DrawCommand::MoveTo, x: x, y: y)
    end

    # Draws a line from the current cursor to `(x, y)`.
    def line_to(x : Float64, y : Float64)
      @operations << CanvasOp.new(command: DrawCommand::LineTo, x: x, y: y)
    end

    # Draws an arc segment with the given radius and angle range.
    def arc(x : Float64, y : Float64, radius : Float64, start_angle : Float64 = 0.0, end_angle : Float64 = Math::PI * 2)
      @operations << CanvasOp.new(command: DrawCommand::Arc, x: x, y: y, radius: radius, start_angle: start_angle, end_angle: end_angle)
    end

    # Fills the current path with `fill_color`.
    def fill(color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0))
      @operations << CanvasOp.new(command: DrawCommand::SetFillColor, color: color)
      @operations << CanvasOp.new(command: DrawCommand::Fill)
    end

    # Strokes the current path with `stroke_color` + `stroke_width`.
    def stroke(color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0), width : Float64 = 1.0)
      @operations << CanvasOp.new(command: DrawCommand::SetStrokeColor, color: color)
      @operations << CanvasOp.new(command: DrawCommand::SetLineWidth, x: width)
      @operations << CanvasOp.new(command: DrawCommand::Stroke)
    end

    # Starts a new sub-path on the canvas.
    def begin_path
      @operations << CanvasOp.new(command: DrawCommand::BeginPath)
    end

    # Closes the current sub-path with a line back to the starting point.
    def close_path
      @operations << CanvasOp.new(command: DrawCommand::ClosePath)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
