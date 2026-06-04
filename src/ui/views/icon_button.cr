# Compact icon-only button used for toolbar and inline actions.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # A button that displays an icon (system symbol or image name) instead of text.
  class IconButton < View
    # Icon name (SF Symbol on Apple, material icon on Android, icon class on web)
    property icon : String

    # Optional text label displayed alongside or below the icon
    property label : String? = nil

    # Icon size in points
    property icon_size : Float64 = 24.0

    # Foreground/tint color
    property tint_color : Color = Color.new(r: 0.0, g: 0.478, b: 1.0)

    # Whether the button is disabled
    property disabled : Bool = false

    # Whether the button paints its platform chrome (a bezel / touch-target box
    # around the glyph). Default `true` keeps the standard button look. Set
    # `false` for a BARE tappable icon (SwiftUI `.buttonStyle(.plain)`) — e.g. an
    # icon+text action row where the glyph should sit flush with no box.
    property bordered : Bool = true

    # Callback on tap
    property on_tap : Proc(Nil)? = nil

    def initialize(@icon : String)
    end

    def initialize(@icon : String, &block : -> Nil)
      @on_tap = block
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:button`.
    def default_accessibility_role : Symbol?
      :button
    end

    # Phase 10B.2b — interactive widgets default to focusable.
    def default_focusable : Bool
      true
    end
  end
end
