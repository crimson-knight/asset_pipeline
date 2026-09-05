# Native map view bridging to MapKit on Apple platforms.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"
require "../../geometry/property_outline"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # iOS-only service-area editing, deliberately separate from price, identity,
  # entitlements and persistence. Keep a stable key for the life of the draft.
  class PropertyMapEditor
    getter key : String
    property initial_outline : AssetPipeline::PropertyOutline::Outline? = nil
    property on_draft_change : Proc(String, Nil)? = nil
    property on_save : Proc(AssetPipeline::PropertyOutline::Outline, Nil)? = nil

    def initialize(@key : String)
      raise ArgumentError.new("Property map editor needs a stable key") if @key.empty? || @key.bytesize > 128
    end
  end

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
    # Validated, keyed Polygon overlays. UIKit only in this first slice.
    property property_outline : AssetPipeline::PropertyOutline::Outline? = nil
    property property_editor : PropertyMapEditor? = nil
    # Camera updates are explicit; unrelated render passes must not reset a pan.
    property camera_revision : Int64 = 0_i64
    property address_label : String = ""

    def initialize
    end

    def accept(visitor : PlatformVisitor)
      {% unless flag?(:ios) %}
        if property_editor || property_outline
          raise NotImplementedError.new("Property outline maps currently require UIKit (-Dios). Supply an explicit platform fallback on other targets.")
        end
      {% end %}
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:group`.
    def default_accessibility_role : Symbol?
      :group
    end
  end
end
