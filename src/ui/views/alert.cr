require "../view"

module UI
  # A modal alert dialog with title, message, and action buttons.
  class Alert < View
    # Alert button definition
    record AlertButton,
      label : String,
      style : Symbol = :default,
      action : Proc(Nil)? = nil

    # Alert title
    property title : String

    # Alert message body
    property message : String = ""

    # Action buttons
    property buttons : Array(AlertButton) = [] of AlertButton

    # Whether the alert is currently presented
    property is_presented : Bool = false

    def initialize(@title : String, @message : String = "")
    end

    # Add a button to the alert with a block action
    def add_button(label : String, style : Symbol = :default, &action : -> Nil)
      @buttons << AlertButton.new(label: label, style: style, action: action)
    end

    # Add a button without action
    def add_button(label : String, style : Symbol = :default)
      @buttons << AlertButton.new(label: label, style: style)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
