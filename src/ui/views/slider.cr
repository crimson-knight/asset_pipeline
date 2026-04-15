require "../view"

module UI
  class Slider < View
    property value : Float64 = 0.0
    property minimum : Float64 = 0.0
    property maximum : Float64 = 1.0
    property step : Float64 = 0.0  # 0 = continuous
    property label : String = ""
    property tint_color : Color? = nil
    property on_change : Proc(Float64, Nil)? = nil

    def initialize(@minimum : Float64 = 0.0, @maximum : Float64 = 1.0, @value : Float64 = 0.0)
    end

    def initialize(@minimum : Float64 = 0.0, @maximum : Float64 = 1.0, @value : Float64 = 0.0, &block : Float64 -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
