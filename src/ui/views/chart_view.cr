require "../view"

module UI
  record ChartDataPoint,
    label : String = "",
    value : Float64 = 0.0,
    color : Color? = nil

  class ChartView < View
    property chart_type : Symbol = :bar # :bar, :line, :pie
    property title : String = ""
    property data_points : Array(ChartDataPoint) = [] of ChartDataPoint
    property show_legend : Bool = true
    property show_grid : Bool = true

    def initialize
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
