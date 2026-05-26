# Native chart view wrapping Swift Charts on Apple platforms and the equivalent on other targets.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  record ChartDataPoint,
    label : String = "",
    value : Float64 = 0.0,
    color : Color? = nil

  # ChartView — Native chart view wrapping Swift Charts on Apple platforms and the equivalent on other targets.
  class ChartView < View
    # Chart variant (e.g. `:line`, `:bar`, `:area`, `:donut`).
    property chart_type : Symbol = :bar # :bar, :line, :pie
    # Primary text shown on the control.
    property title : String = ""
    # Numeric data series rendered by the chart.
    property data_points : Array(ChartDataPoint) = [] of ChartDataPoint
    # Boolean toggle.
    property show_legend : Bool = true
    # Boolean toggle.
    property show_grid : Bool = true

    def initialize
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:img`.
    def default_accessibility_role : Symbol?
      :img
    end
  end
end
