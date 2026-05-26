# Two-dimensional layout that arranges children in rows and columns.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Grid — Two-dimensional layout that arranges children in rows and columns.
  class Grid < View
    record Column,
      alignment : Alignment = Alignment::Leading,
      minimum_width : Float64? = nil

    property children : Array(Array(View)) = [] of Array(View)
    property columns : Array(Column) = [] of Column
    # Vertical gap (in pt) between rows.
    property row_spacing : Float64 = 8.0
    # Horizontal gap (in pt) between columns.
    property column_spacing : Float64 = 8.0
    # Cross-axis alignment for children. See `UI::Alignment`.
    property alignment : Alignment = Alignment::Leading

    def initialize(@columns : Array(Column) = [] of Column)
    end

    # Add a row of views
    def add_row(views : Array(View))
      @children << views
    end

    # Convenience to add a row with a block
    def add_row(&)
      row = [] of View
      yield row
      @children << row
    end

    # Returns the number of rows currently configured.
    def row_count : Int32
      @children.size
    end

    # Returns the number of columns currently configured.
    def column_count : Int32
      columns.empty? ? (@children.first?.try(&.size) || 0) : columns.size
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:grid`.
    def default_accessibility_role : Symbol?
      :grid
    end
  end
end
