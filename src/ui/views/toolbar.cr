require "../view"

module UI
  class Toolbar < View
    record ToolbarItem,
      id : String = "",
      label : String = "",
      icon : String? = nil,
      action : Proc(Nil)? = nil

    property items : Array(ToolbarItem) = [] of ToolbarItem
    property title : String? = nil
    property shows_title : Bool = true

    def initialize(@title : String? = nil)
    end

    def add_item(id : String, label : String, icon : String? = nil, &block : -> Nil)
      @items << ToolbarItem.new(id: id, label: label, icon: icon, action: block)
    end

    def add_item(id : String, label : String, icon : String? = nil)
      @items << ToolbarItem.new(id: id, label: label, icon: icon)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
