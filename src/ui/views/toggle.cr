require "../view"

module UI
  class Toggle < View
    property is_on : Bool = false
    property label : String = ""
    property style : ToggleStyle = ToggleStyle::Switch
    property tint_color : Color? = nil
    property on_change : Proc(Bool, Nil)? = nil
    # Whether the toggle is non-interactive (grayed out).
    # Maps to NSButton setEnabled:NO (AppKit) and UISwitch setEnabled:NO (UIKit).
    property disabled : Bool = false

    def initialize(@label : String = "", @is_on : Bool = false)
    end

    def initialize(@label : String = "", @is_on : Bool = false, &block : Bool -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
