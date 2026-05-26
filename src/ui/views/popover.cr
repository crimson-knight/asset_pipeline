# Lightweight transient overlay anchored to a host view.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Popover — Lightweight transient overlay anchored to a host view.
  class Popover < View
    # Child view rendered inside this container.
    property content : View? = nil
    # Whether the modal / overlay is currently presented.
    property is_presented : Bool = false
    # Edge the popover's arrow points at (`:top`, `:bottom`, `:leading`, `:trailing`).
    property arrow_edge : Symbol = :bottom # :top, :bottom, :leading, :trailing
    # Numeric value (pt unless otherwise noted).
    property preferred_width : Float64? = nil
    # Numeric value (pt unless otherwise noted).
    property preferred_height : Float64? = nil
    # Invoked when the overlay is dismissed (by tap-outside, escape, or programmatic close).
    property on_dismiss : Proc(Nil)? = nil

    # Phase 5 v2 — Apple semantic material override. nil = HIG-canonical
    # default :popover (NSVisualEffectMaterialPopover on macOS,
    # .regularMaterial via .presentationBackground on iOS 16.4+).
    property material_semantic : Symbol? = nil

    def initialize(@content : View? = nil, @arrow_edge : Symbol = :bottom)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:dialog`.
    def default_accessibility_role : Symbol?
      :dialog
    end
  end

  # Presentation state for a Popover (is_presenting flag + the underlying view).
  class PopoverPresenter
    # The Popover instance being presented.
    property popover : Popover
    # The anchor view the popover is positioned relative to.
    property anchor : View? = nil
    # Whether the controller is in the act of presenting the overlay.
    property is_presenting : Bool = false

    def initialize(@popover : Popover, @anchor : View? = nil)
    end

    # Presents the overlay / modal.
    def present
      @is_presenting = true
      @popover.is_presented = true
    end

    # Dismisses the overlay / modal.
    def dismiss
      @is_presenting = false
      @popover.is_presented = false
      @popover.on_dismiss.try(&.call)
    end
  end
end
