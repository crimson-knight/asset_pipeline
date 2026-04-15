require "../view"

module UI
  class Checkbox < View
    property is_checked : Bool = false
    property label : String = ""
    property on_change : Proc(Bool, Nil)? = nil

    def initialize(@label : String = "", @is_checked : Bool = false)
    end

    def initialize(@label : String = "", @is_checked : Bool = false, &block : Bool -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
