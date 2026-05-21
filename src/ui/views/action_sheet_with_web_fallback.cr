require "../view"
require "./action_sheet"

# NOTE (Phase 4 — un-gated shell). Commit 4 splits this into a conditional
# delegate (iOS branch holds a UI::ActionSheet and forwards `accept`) and a
# stand-alone fallback that runs visitor.visit(self) on every other target.
module UI
  # Cross-platform companion to the iOS-only `UI::ActionSheet`.
  #
  # On `-Dios`: holds a `UI::ActionSheet` instance and forwards `accept` so
  # the iOS visitor renders the native sheet (currently via
  # `ConfirmationDialogFacade`; see `UI::ActionSheet` for the N→2 mapping
  # caveat).
  #
  # On every other platform: renders directly. The web visitor produces a
  # `role="dialog"` bottom-sheet with backdrop, focus trap, and
  # escape-to-dismiss (see `src/ui/web/action_sheet_fallback.js`). The macOS
  # and Android visitors render a styled modal panel (delegates to
  # `ConfirmationDialog` semantics).
  class ActionSheetWithWebFallback < View
    record Action,
      label : String,
      style : Symbol = :default, # :default | :destructive | :cancel
      action : Proc(Nil)? = nil

    property title : String = ""
    property message : String = ""
    property actions : Array(Action) = [] of Action
    property is_presented : Bool = false

    def initialize(@title : String = "", @message : String = "")
    end

    def add_action(label : String, style : Symbol = :default, &block : -> Nil)
      @actions << Action.new(label: label, style: style, action: block)
    end

    def add_action(label : String, style : Symbol = :default)
      @actions << Action.new(label: label, style: style)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
