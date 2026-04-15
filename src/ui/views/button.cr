require "../view"

module UI
  # Visual presentation style for UI::Button.
  #
  # Maps to UIButton.Configuration variants on iOS 15+ and to NSButton
  # bezel / fill attributes on macOS. HIG: "Use a consistent style to help
  # people understand which buttons perform primary versus secondary actions."
  #
  #   Default    — bordered system button. UIButton.Configuration.gray() /
  #                NSBezelStyleRounded. The standard interactive affordance
  #                for most secondary and utility actions.
  #   Prominent  — filled blue (or red when role == :destructive). Primary
  #                call-to-action per HIG: "Use a filled button for the most
  #                likely action in a view." UIButton.Configuration.filled() /
  #                NSButton with bezelColor = controlAccentColor.
  #   Tinted     — translucent tint fill, a softer alternative to Prominent
  #                for secondary CTAs. UIButton.Configuration.tinted() /
  #                NSButton with NSBezelStyleFlexiblePush.
  #   Bordered   — explicit bordered button (same as Default on most surfaces;
  #                use when you want to be explicit in code). Resolves
  #                identically to Default in both renderers.
  #   Borderless — no bezel; label text only. UIButton.Configuration.plain() /
  #                NSButton with isBordered = false. Use for low-prominence
  #                inline actions (e.g. "Learn more", "See details").
  enum ButtonStyle
    Default
    Prominent
    Tinted
    Bordered
    Borderless
  end

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

    # Semantic role for the button. HIG-standard values:
    #   :default      — normal/primary action (no special styling)
    #   :destructive  — action destroys data; renderers color the label red
    #   :cancel       — dismisses a presentation surface; renderers weight
    #                   the label Semibold per HIG
    property role : Symbol = :default

    # Visual style. See ButtonStyle for full documentation.
    # Default renders as a system bordered button; override to Prominent for
    # filled-blue primary CTAs or Borderless for text-link style.
    property style : ButtonStyle = ButtonStyle::Default

    # Leading SF Symbol glyph name (macOS 11+ / iOS 13+). When non-nil the
    # renderers prepend an SF Symbol image to the button. Unknown symbol
    # names are silently skipped rather than crashing.
    property symbol : String? = nil

    def initialize(@label : String, *, @role : Symbol = :default, @style : ButtonStyle = ButtonStyle::Default, @symbol : String? = nil)
    end

    # Convenience constructor that accepts a tap handler block
    def initialize(@label : String, *, @role : Symbol = :default, @style : ButtonStyle = ButtonStyle::Default, @symbol : String? = nil, &block : -> Nil)
      @on_tap = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
