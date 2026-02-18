require "../view"

module UI
  # A tappable button with a text label and optional action callback.
  #
  # The `on_tap` proc is invoked when the button is activated.
  # Buttons can be disabled to prevent interaction.
  class Button < View
    # The button's display label
    property label : String

    # Font for the button label
    property font : Font = Font.new

    # Foreground (label) color
    property foreground_color : Color = Color.new(r: 0.0, g: 0.478, b: 1.0)

    # Whether the button is disabled (non-interactive)
    property disabled : Bool = false

    # Callback invoked when the button is tapped
    property on_tap : Proc(Nil)? = nil

    def initialize(@label : String)
    end

    # Convenience constructor that accepts a tap handler block
    def initialize(@label : String, &block : -> Nil)
      @on_tap = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
