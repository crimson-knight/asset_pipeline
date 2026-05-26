# Native video playback view bridging to AVPlayerViewController on Apple platforms.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # VideoPlayer — Native video playback view bridging to AVPlayerViewController on Apple platforms.
  class VideoPlayer < View
    # URL the view points at.
    property url : String = ""
    # Boolean toggle.
    property is_playing : Bool = false
    # Boolean toggle.
    property shows_controls : Bool = true
    # Boolean toggle.
    property auto_play : Bool = false
    # Boolean toggle.
    property muted : Bool = false
    # Boolean toggle.
    property loop : Bool = false
    # Text value.
    property poster_url : String? = nil

    def initialize(@url : String = "")
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
