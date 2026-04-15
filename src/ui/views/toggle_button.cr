require "../view"

module UI
  class ToggleButton < View
    property label : String
    property is_selected : Bool = false
    property icon : String? = nil
    property on_toggle : Proc(Bool, Nil)? = nil

    def initialize(@label : String, @is_selected : Bool = false)
    end

    def initialize(@label : String, @is_selected : Bool = false, &block : Bool -> Nil)
      @on_toggle = block
    end

    def toggle
      @is_selected = !@is_selected
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
