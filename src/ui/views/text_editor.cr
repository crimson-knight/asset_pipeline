# Rich multi-line text editor with attributed string support.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # TextEditor — Rich multi-line text editor with attributed string support.
  class TextEditor < View
    # Body text rendered by the view.
    property text : String = ""
    # Placeholder text shown when the field is empty.
    property placeholder : String = ""
    # Typography applied to the rendered text.
    property font : Font = Font.new
    # Foreground color applied to the text. Overrides any role token.
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
    # Boolean toggle.
    property is_editable : Bool = true
    # Boolean toggle.
    property shows_line_numbers : Bool = false
    property syntax_highlighting : Symbol? = nil # :crystal, :json, :markdown, etc.
    # Invoked when the user changes the control's value.
    property on_change : Proc(String, Nil)? = nil

    def initialize(@placeholder : String = "")
    end

    def initialize(@placeholder : String = "", &block : String -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:text_field`.
    def default_accessibility_role : Symbol?
      :text_field
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
