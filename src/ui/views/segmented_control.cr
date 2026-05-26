# Horizontal segmented selector for picking one option from a small set.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # SegmentedControl — Horizontal segmented selector for picking one option from a small set.
  class SegmentedControl < View
    # Ordered list of option labels.
    property segments : Array(String) = [] of String
    # Currently selected index into the segments / options array.
    property selected_index : Int32 = 0
    # Invoked when the user changes the control's value.
    property on_change : Proc(Int32, Nil)? = nil

    def initialize(@segments : Array(String) = [] of String, @selected_index : Int32 = 0)
    end

    def initialize(@segments : Array(String), @selected_index : Int32 = 0, &block : Int32 -> Nil)
      @on_change = block
    end

    # Returns the selected segment label (or nil if no valid selection).
    def selected_segment : String?
      if selected_index >= 0 && selected_index < segments.size
        segments[selected_index]
      end
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:tab_list`.
    def default_accessibility_role : Symbol?
      :tab_list
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
