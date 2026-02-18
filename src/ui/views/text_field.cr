require "../view"

module UI
  # An editable single-line text input field.
  #
  # Provides placeholder text, secure entry mode for passwords,
  # keyboard type hints, and a change callback.
  class TextField < View
    # Current text value
    property text : String = ""

    # Placeholder text shown when empty
    property placeholder : String = ""

    # Font for the text field content
    property font : Font = Font.new

    # Text color
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)

    # Whether input is obscured (password entry)
    property secure_entry : Bool = false

    # Keyboard type hint for platform input method
    property keyboard_type : KeyboardType = KeyboardType::Default

    # Callback invoked when the text value changes.
    # Receives the new text string.
    property on_change : Proc(String, Nil)? = nil

    def initialize(@placeholder : String = "")
    end

    # Convenience constructor with a change handler block
    def initialize(@placeholder : String = "", &block : String -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
