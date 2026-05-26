# Apple glass / translucency background using NSVisualEffectView / UIVisualEffectView.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # GlassBackground — Apple glass / translucency background using NSVisualEffectView / UIVisualEffectView.
  class GlassBackground < View
    # Child view rendered inside this container.
    property content : View? = nil
    # Surface material applied to the background (e.g. `:primary`, `:secondary`, `:thin`).
    property material : Symbol = :regular # :thin, :ultra_thin, :regular, :thick, :chrome
    # Boolean toggle.
    property is_vibrant : Bool = true

    def initialize(@content : View? = nil, @material : Symbol = :regular)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
