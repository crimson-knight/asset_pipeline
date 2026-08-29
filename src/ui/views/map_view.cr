# Native map view bridging to MapKit on Apple platforms.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  record MapAnnotation,
    latitude : Float64,
    longitude : Float64,
    title : String = "",
    subtitle : String? = nil

  # MapView — Native map view bridging to MapKit on Apple platforms.
  class MapView < View
    # Numeric value (pt unless otherwise noted).
    property latitude : Float64 = 0.0
    # Numeric value (pt unless otherwise noted).
    property longitude : Float64 = 0.0
    # Numeric value (pt unless otherwise noted).
    property zoom_level : Float64 = 10.0
    # Map presentation style (e.g. `:standard`, `:satellite`, `:hybrid`).
    property map_type : Symbol = :standard # :standard, :satellite, :hybrid
    # Boolean toggle.
    property shows_user_location : Bool = false
    # Annotations rendered on top of the map.
    property annotations : Array(MapAnnotation) = [] of MapAnnotation

    def initialize
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:group`.
    def default_accessibility_role : Symbol?
      :group
    end
  end
end
