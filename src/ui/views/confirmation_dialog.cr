# Action-confirmation prompt with platform-idiomatic destructive/cancel buttons.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # ConfirmationDialog — Action-confirmation prompt with platform-idiomatic destructive/cancel buttons.
  class ConfirmationDialog < View
    # Primary text shown on the control.
    property title : String
    # Body / message text shown in the alert / dialog.
    property message : String = ""
    # Whether the modal / overlay is currently presented.
    property is_presented : Bool = false
    # Text value.
    property confirm_label : String = "Confirm"
    # Text value.
    property cancel_label : String = "Cancel"
    property confirm_style : Symbol = :default # :default, :destructive
    property on_confirm : Proc(Nil)? = nil
    property on_cancel : Proc(Nil)? = nil

    def initialize(@title : String, @message : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:alert`.
    def default_accessibility_role : Symbol?
      :alert
    end
  end
end
