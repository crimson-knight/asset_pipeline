require "../view"

module UI
  class NavigationSplitView < View
    property sidebar : View? = nil
    property content : View? = nil
    property detail : View? = nil
    property sidebar_width : Float64 = 250.0
    property shows_sidebar : Bool = true
    property column_visibility : Symbol = :all  # :all, :double_column, :detail_only

    def initialize(@sidebar : View? = nil, @content : View? = nil, @detail : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
