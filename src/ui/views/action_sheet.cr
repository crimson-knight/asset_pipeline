require "../view"

# NOTE (Phase 4 — un-gated shell). The Tier 3 compile-time gate is applied
# in Commit 4. This file currently builds on every platform so that the
# WithWebFallback sibling, renderer wiring, and specs can be developed
# against a working class. Commit 4 wraps the class body in a
# flag?(:ios) macro guard with an actionable compile-time raise.
module UI
  # iOS-only action sheet (Tier 3 after Commit 4).
  #
  # On iOS, this view is rendered through SwiftUI's `.confirmationDialog`
  # modifier via `ConfirmationDialogFacade`. The Phase 3 facade currently
  # supports a binary confirm + cancel pair only, so iOS rendering reduces
  # an N-action sheet to {first non-cancel action, cancel action}; additional
  # actions are dropped at render time. Phase 5 work will extend the SwiftKit
  # bridge with a multi-action facade.
  #
  # For cross-platform usage that needs an action-sheet UX everywhere, use
  # `UI::ActionSheetWithWebFallback` — it delegates to this class on iOS and
  # renders a self-contained vanilla-JS bottom sheet on web (and falls back
  # to ConfirmationDialog semantics on macOS / Android).
  class ActionSheet < View
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

    # First non-cancel action, used by the Phase 4 iOS routing as the
    # `confirm` button when degrading the sheet to ConfirmationDialog. Returns
    # `nil` if every action has `style == :cancel`.
    def primary_action : Action?
      @actions.find { |a| a.style != :cancel }
    end

    # The cancel-style action, if the developer added one explicitly.
    def cancel_action : Action?
      @actions.find { |a| a.style == :cancel }
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
