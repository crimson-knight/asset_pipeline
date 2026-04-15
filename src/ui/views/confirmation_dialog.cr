require "../view"

module UI
  class ConfirmationDialog < View
    property title : String
    property message : String = ""
    property is_presented : Bool = false
    property confirm_label : String = "Confirm"
    property cancel_label : String = "Cancel"
    property confirm_style : Symbol = :default  # :default, :destructive
    property on_confirm : Proc(Nil)? = nil
    property on_cancel : Proc(Nil)? = nil

    def initialize(@title : String, @message : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
