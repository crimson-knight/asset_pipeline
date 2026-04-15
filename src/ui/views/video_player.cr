require "../view"

module UI
  class VideoPlayer < View
    property url : String = ""
    property is_playing : Bool = false
    property shows_controls : Bool = true
    property auto_play : Bool = false
    property muted : Bool = false
    property loop : Bool = false
    property poster_url : String? = nil

    def initialize(@url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
