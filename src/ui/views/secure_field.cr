require "../view"

module UI
  # A password/secure text input field.
  # This is a convenience wrapper around TextField with secure_entry = true.
  class SecureField < View
    property text : String = ""
    property placeholder : String = ""
    property font : Font = Font.new
    property text_color : Color = Color.new(r: 0.0, g: 0.0, b: 0.0)
    property on_change : Proc(String, Nil)? = nil

    def initialize(@placeholder : String = "")
    end

    def initialize(@placeholder : String = "", &block : String -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
