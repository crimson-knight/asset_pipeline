require "../view"

module UI
  class GlassBackground < View
    property content : View? = nil
    property material : Symbol = :regular  # :thin, :ultra_thin, :regular, :thick, :chrome
    property is_vibrant : Bool = true

    def initialize(@content : View? = nil, @material : Symbol = :regular)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
