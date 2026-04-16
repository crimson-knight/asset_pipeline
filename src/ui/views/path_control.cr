require "../view"

module UI
  enum PathControlStyle
    Standard
    PopUp
  end

  class PathControl < View
    record Component,
      name : String,
      icon : String? = nil,
      url : String? = nil

    property components : Array(Component) = [] of Component
    property style : PathControlStyle = PathControlStyle::Standard
    property is_editable : Bool = false

    def initialize(
      @components : Array(Component) = [] of Component,
      @style : PathControlStyle = PathControlStyle::Standard
    )
    end

    def add_component(name : String, icon : String? = nil, url : String? = nil)
      @components << Component.new(name: name, icon: icon, url: url)
    end

    def path_string : String
      return "/" if @components.empty?
      "/" + @components.map(&.name).join("/")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
