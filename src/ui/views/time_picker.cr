require "../view"

module UI
  class TimePicker < View
    property selected_time : Time = Time.utc
    property shows_24_hour : Bool = false
    property minute_interval : Int32 = 1
    property label : String = ""
    property on_change : Proc(Time, Nil)? = nil

    def initialize(@shows_24_hour : Bool = false)
    end

    def initialize(@shows_24_hour : Bool = false, &block : Time -> Nil)
      @on_change = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
