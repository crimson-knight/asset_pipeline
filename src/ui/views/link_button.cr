require "../view"

module UI
  class LinkButton < View
    property label : String
    property url : String = ""
    property opens_in_browser : Bool = true
    property on_tap : Proc(Nil)? = nil

    def initialize(@label : String, @url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
