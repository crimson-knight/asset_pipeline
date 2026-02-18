require "../view"

module UI
  # A scrollable container for a single child view tree.
  #
  # Wraps content that may exceed the visible area, allowing
  # the user to scroll horizontally, vertically, or both.
  class ScrollView < View
    # The content view (typically a stack)
    property content : View? = nil

    # Whether horizontal scrolling is enabled
    property scroll_horizontal : Bool = false

    # Whether vertical scrolling is enabled
    property scroll_vertical : Bool = true

    # Whether scroll indicators are shown
    property shows_indicators : Bool = true

    def initialize(@content : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
