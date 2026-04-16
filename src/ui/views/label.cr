require "../view"
require "../theme"

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

    # Text color (brand / explicit RGBA override). Only consulted when
    # `text_color_role` is nil — otherwise the role resolves to the
    # appearance-tracking system color and this RGBA is ignored.
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)

    # Semantic Apple label-color role. When set, the AppKit / UIKit renderer
    # resolves to `NSColor.labelColor` / `UIColor.labelColor` (and secondary
    # / tertiary / quaternary variants) at render time, tracking appearance
    # automatically. Default is `LabelRole::Primary` — the beauty-by-default
    # HIG render. A host that wants a brand color sets `text_color_role = nil`
    # and sets `text_color` to the brand RGBA. Web / Android renderers ignore
    # this field.
    property text_color_role : LabelRole? = LabelRole::Primary

    # Text alignment within the label bounds
    property text_alignment : Alignment = Alignment::Leading

    # Maximum number of lines (0 means unlimited)
    property number_of_lines : Int32 = 0

    # Preferred wrapping width for native multi-line layout engines.
    #
    # UIKit's UILabel uses this to compute a stable multi-line intrinsic
    # content size when it is inside exact-width containers like UI::Card.
    # Other renderers may ignore it.
    property preferred_max_layout_width : Float64? = nil

    def initialize(@text : String)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
