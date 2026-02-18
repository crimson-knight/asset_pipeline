require "../view"

module UI
  # A vertical stack layout that arranges children top to bottom.
  #
  # Children are laid out sequentially along the vertical axis
  # with configurable spacing and alignment.
  class VStack < View
    # Spacing between children in points
    property spacing : Float64 = 8.0

    # Horizontal alignment of children within the stack
    property alignment : Alignment = Alignment::Center

    # Ordered list of child views
    getter children : Array(View) = [] of View

    def initialize(@spacing : Float64 = 8.0, @alignment : Alignment = Alignment::Center)
    end

    # Append a child view. Returns self for chaining.
    def <<(child : View) : self
      @children << child
      self
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
