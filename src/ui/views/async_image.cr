require "../view"

module UI
  class AsyncImage < View
    property url : String = ""
    property placeholder : View? = nil
    property content_mode : ContentMode = ContentMode::Fit
    property is_loading : Bool = false
    property error_message : String? = nil
    property on_load : Proc(Nil)? = nil
    property on_error : Proc(String, Nil)? = nil

    def initialize(@url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
