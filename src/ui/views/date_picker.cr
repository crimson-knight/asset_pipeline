# Calendar-based date selection control.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # DatePicker — Calendar-based date selection control.
  class DatePicker < View
    property selected_date : Time = Time.utc
    property mode : DatePickerMode = DatePickerMode::Date
    property minimum_date : Time? = nil
    property maximum_date : Time? = nil
    property label : String = ""
    property on_change : Proc(Time, Nil)? = nil

    def initialize(@mode : DatePickerMode = DatePickerMode::Date)
    end

    def initialize(@mode : DatePickerMode = DatePickerMode::Date, &block : Time -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:group`.
    def default_accessibility_role : Symbol?
      :group
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
