require "../view"

module UI
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
  end
end
