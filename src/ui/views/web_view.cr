require "../view"

module UI
  class WebViewComponent < View
    property url : String = ""
    property html : String? = nil
    property base_url : String? = nil
    property allows_navigation : Bool = true
    property allows_scripts : Bool = true
    property title : String? = nil

    def initialize(@url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
