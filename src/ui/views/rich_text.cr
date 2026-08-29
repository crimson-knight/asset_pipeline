# Read-only rich-text view supporting attributed runs and inline images.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # RichText — Read-only rich-text view supporting attributed runs and inline images.
  class RichText < View
    record Span,
      text : String = "",
      font : Font = Font.new,
      color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0),
      bold : Bool = false,
      italic : Bool = false,
      underline : Bool = false,
      strikethrough : Bool = false,
      link : String? = nil

    # Styled text runs that make up the rich-text content.
    property spans : Array(Span) = [] of Span
    # Horizontal text alignment.
    property text_alignment : Alignment = Alignment::Leading

    def initialize
    end

    # Appends a styled span to the rich-text run.
    def add_span(text : String, bold : Bool = false, italic : Bool = false, color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0))
      @spans << Span.new(text: text, bold: bold, italic: italic, color: color)
    end

    # Returns the unstyled plain-text content.
    def plain_text : String
      spans.map(&.text).join
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:text`.
    def default_accessibility_role : Symbol?
      :text
    end
  end
end
