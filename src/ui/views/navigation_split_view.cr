require "../view"

module UI
  class NavigationSplitView < View
    property sidebar : View? = nil
    property content : View? = nil
    property detail : View? = nil
    property sidebar_width : Float64 = 250.0
    property shows_sidebar : Bool = true
    property column_visibility : Symbol = :all # :all, :double_column, :detail_only

    def initialize(@sidebar : View? = nil, @content : View? = nil, @detail : View? = nil)
      # Default container-query root: the split view's sidebar/content
      # ratio depends on its own width, not the viewport. Naming it
      # `split-view` lets the registered class CSS and inline render
      # output expose the same `@container split-view (...)` contract.
      @container_query_name = "split-view"
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
