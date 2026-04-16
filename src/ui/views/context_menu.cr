require "../view"

module UI
  class ContextMenu < View
    record Item,
      label : String,
      icon : String? = nil,
      is_destructive : Bool = false,
      is_disabled : Bool = false,
      action : Proc(Nil)? = nil

    struct Separator
    end

    alias Entry = Item | Separator

    property items : Array(Entry) = [] of Entry

    def initialize
    end

    def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false, &block : -> Nil)
      @items << Item.new(
        label: label,
        icon: icon,
        is_destructive: is_destructive,
        is_disabled: is_disabled,
        action: block
      )
    end

    def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false)
      @items << Item.new(
        label: label,
        icon: icon,
        is_destructive: is_destructive,
        is_disabled: is_disabled
      )
    end

    def add_separator
      @items << Separator.new
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
