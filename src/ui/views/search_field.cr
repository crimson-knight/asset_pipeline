# Single-line search input with platform-idiomatic clear and scope affordances.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # SearchField — Single-line search input with platform-idiomatic clear and scope affordances.
  class SearchField < View
    # Body text rendered by the view.
    property text : String = ""
    # Placeholder text shown when the field is empty.
    property placeholder : String = "Search"
    # Boolean toggle.
    property is_searching : Bool = false
    # Boolean toggle.
    property shows_cancel_button : Bool = true
    # Invoked when the user changes the control's value.
    property on_change : Proc(String, Nil)? = nil
    # Invoked when the user submits the field (Return / Enter).
    property on_submit : Proc(String, Nil)? = nil
    property on_cancel : Proc(Nil)? = nil

    def initialize(@placeholder : String = "Search")
    end

    def initialize(@placeholder : String = "Search", &block : String -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:search`.
    def default_accessibility_role : Symbol?
      :search
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
