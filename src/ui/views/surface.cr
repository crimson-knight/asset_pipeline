require "../view"

module UI
  class Surface < View
    property content : View? = nil
    property elevation : Float64 = 0.0
    property tonal_elevation : Float64 = 0.0
    property shape : Symbol = :rectangle  # :rectangle, :rounded, :circle

    def initialize(@content : View? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
