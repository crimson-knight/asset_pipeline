# Button styled as a hyperlink that opens or dispatches a navigation action.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # LinkButton — Button styled as a hyperlink that opens or dispatches a navigation action.
  class LinkButton < View
    # Caption / accessibility label rendered alongside the control.
    property label : String
    # URL the view points at.
    property url : String = ""
    # Boolean toggle.
    property opens_in_browser : Bool = true
    # Invoked when the user taps / clicks the control.
    property on_tap : Proc(Nil)? = nil

    def initialize(@label : String, @url : String = "")
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:link`.
    def default_accessibility_role : Symbol?
      :link
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
