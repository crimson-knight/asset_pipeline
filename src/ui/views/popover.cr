require "../view"

module UI
  class Popover < View
    property content : View? = nil
    property is_presented : Bool = false
    property arrow_edge : Symbol = :bottom  # :top, :bottom, :leading, :trailing
    property preferred_width : Float64? = nil
    property preferred_height : Float64? = nil
    property on_dismiss : Proc(Nil)? = nil

    # Phase 5 v2 — Apple semantic material override. nil = HIG-canonical
    # default :popover (NSVisualEffectMaterialPopover on macOS,
    # .regularMaterial via .presentationBackground on iOS 16.4+).
    property material_semantic : Symbol? = nil

    def initialize(@content : View? = nil, @arrow_edge : Symbol = :bottom)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end

  class PopoverPresenter
    property popover : Popover
    property anchor : View? = nil
    property is_presenting : Bool = false

    def initialize(@popover : Popover, @anchor : View? = nil)
    end

    def present
      @is_presenting = true
      @popover.is_presented = true
    end

    def dismiss
      @is_presenting = false
      @popover.is_presented = false
      @popover.on_dismiss.try(&.call)
    end
  end
end
