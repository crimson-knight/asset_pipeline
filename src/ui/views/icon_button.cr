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

    # Icon size in points (square shorthand; used when icon_width/icon_height are nil).
    property icon_size : Float64 = 24.0

    # Explicit non-square icon dimensions (points). When set, these override
    # icon_size. The facade renders the icon into an exact W×H frame using
    # cover-crop (.fill contentMode) so the asset is never distorted.
    # Example: hamburger menu icon rendered 22×18 from a 66×54 @3x source.
    property icon_width : Float64? = nil
    property icon_height : Float64? = nil

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

    # B2.1 — the icon's effective horizontal footprint in points. `icon_width`
    # (the non-square cover-crop dimension) takes precedence over the square
    # `icon_size` shorthand. A BARE icon (`bordered == false`) renders the glyph
    # flush with no chrome, so this width also equals the host UIView's footprint
    # — the uikit renderer pins the host to it so the IconButton hugs its icon box
    # in an HStack instead of stretching under UIStackView's .fill distribution.
    # A bordered icon adds platform-button chrome insets, so the host is wider
    # than the icon box; callers must not pin a bordered host to this value.
    def effective_icon_box_width : Float64
      icon_width || icon_size
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
