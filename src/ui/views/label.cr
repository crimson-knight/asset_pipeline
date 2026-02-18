require "../view"

module UI
  # A read-only text label.
  #
  # Displays a single or multi-line string with configurable font,
  # color, alignment, and line limit.
  class Label < View
    # The text content to display
    property text : String

    # Font specification for the label text
    property font : Font = Font.new

    # Text color
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)

    # Text alignment within the label bounds
    property text_alignment : Alignment = Alignment::Leading

    # Maximum number of lines (0 means unlimited)
    property number_of_lines : Int32 = 0

    def initialize(@text : String)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
