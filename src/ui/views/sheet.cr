require "../view"

module UI
  class Sheet < View
    property content : View? = nil
    property is_presented : Bool = false
    property shows_drag_indicator : Bool = true
    property detents : Array(Symbol) = [:medium, :large]  # :small, :medium, :large, :custom
    property selected_detent : Symbol = :medium
    property on_dismiss : Proc(Nil)? = nil

    # HIG surface-chrome style. Controls how renderers paint the sheet's
    # container when rendering inline (i.e., when is_presented is false or
    # the visitor is drawing the content directly into the host view).
    #   :auto         — render with HIG grouped-card chrome by default
    #                   (rounded corners, grouped-background fill, 16pt
    #                   padding). This is the default so inline sheet
    #                   content reads like a real HIG presentation surface.
    #   :grouped_card — explicit grouped-card chrome.
    #   :plain        — no chrome; act as a bare container.
    property surface_style : Symbol = :auto

    def initialize(@content : View? = nil, *, @surface_style : Symbol = :auto)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end

  class SheetPresenter
    property sheet : Sheet
    property is_presenting : Bool = false

    def initialize(@sheet : Sheet)
    end

    def present
      @is_presenting = true
      @sheet.is_presented = true
    end

    def dismiss
      @is_presenting = false
      @sheet.is_presented = false
      @sheet.on_dismiss.try(&.call)
    end
  end
end
