# Native share / activity sheet for exporting content to other apps.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Struct representing a share destination in the horizontal destination row.
  # HIG: "Activity views present sharing activities like messaging and actions
  # like Copy and Print, in addition to quick access to frequently used apps."
  # Each destination is a circular icon (~60pt) with a label below it.
  struct ActivityDestination
    # SF Symbol name (Apple) / icon identifier (Android / web) for the icon.
    property icon_symbol : String # SF Symbol name (e.g. "envelope", "message")
    # Caption / accessibility label rendered alongside the control.
    property label : String
    # Invoked with the newly-selected item when the user picks an option.
    property on_select : Proc(Nil)?

    def initialize(@icon_symbol : String, @label : String, @on_select : Proc(Nil)? = nil)
    end
  end

  # Struct representing an action tile in the 2-column action grid.
  # HIG: "Activity views present... actions like Copy and Print."
  # Each action tile is a rounded-rect button with icon + label,
  # laid out in a two-column grid below the destination row.
  struct ActivityAction
    # SF Symbol name (Apple) / icon identifier (Android / web) for the icon.
    property icon_symbol : String # SF Symbol name (e.g. "doc.on.doc", "printer")
    # Caption / accessibility label rendered alongside the control.
    property label : String
    # Invoked with the newly-selected item when the user picks an option.
    property on_select : Proc(Nil)?
    # Semantic role (e.g. `:primary`, `:destructive`, `:cancel`).
    property role : Symbol? # :destructive to render label red; nil for default

    def initialize(@icon_symbol : String, @label : String,
                   @on_select : Proc(Nil)? = nil, @role : Symbol? = nil)
    end
  end

  # UI::ActivityView — share sheet / activity view component.
  #
  # HIG abstract: "An activity view — often called a share sheet — presents
  # a range of tasks that people can perform in the current context."
  #
  # Layout (four zones, top-to-bottom):
  #   1. Header:       HStack(thumbnail, VStack(title, subtitle))
  #   2. Destinations: horizontal ScrollView of circular destination glyphs
  #                    (~60pt) with labels below each.
  #   3. Actions:      two-column grid of action tiles (icon + label).
  #   4. Cancel:       full-width semibold Cancel button at bottom.
  #
  # HIG Platform considerations: "Not supported in macOS, tvOS, or watchOS."
  # On macOS the renderer emits an NSVisualEffectView popover approximation
  # with all four zones rendered inline for validation, while runtime sharing
  # can present NSSharingServicePicker from the same view model. On iOS the
  # visitor renders inline for the validation capture path and presents
  # UIActivityViewController when `is_presented` is true and a share payload
  # is present.
  #
  # Glass material: NSVisualEffectMaterialPopover (6) on macOS;
  # UIBlurEffect(systemChromeMaterial) / UIGlassEffect on iOS 26.
  class ActivityView < View
    # Presentation state. When true and share payload is present, native
    # renderers present the platform share UI in addition to the inline
    # validation layout used for previews.
    property is_presented : Bool = false

    # Optional native share payload. These values power UIActivityViewController
    # / NSSharingServicePicker for real app flows.
    property share_text : String? = nil
    # Text value.
    property share_url : String? = nil
    # Text value.
    property share_subject : String? = nil

    # Zone 1 — Header
    property title : String
    # Secondary line shown beneath the title.
    property subtitle : String?
    # Optional thumbnail image source.
    property thumbnail : View? # Optional preview; typically UI::Image

    # Zone 2 — Horizontal destination row
    property destinations : Array(ActivityDestination) = [] of ActivityDestination

    # Zone 3 — Action tile grid
    property actions : Array(ActivityAction) = [] of ActivityAction

    # Zone 4 — Cancel
    property on_cancel : Proc(Nil)?

    def initialize(@title : String,
                   @subtitle : String? = nil,
                   @thumbnail : View? = nil,
                   @destinations : Array(ActivityDestination) = [] of ActivityDestination,
                   @actions : Array(ActivityAction) = [] of ActivityAction,
                   @on_cancel : Proc(Nil)? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end

  # Presentation state for an ActivityView share sheet.
  class ActivityViewPresenter
    # The ActivityView instance being presented.
    property activity_view : ActivityView
    # Whether the controller is in the act of presenting the overlay.
    property is_presenting : Bool = false

    def initialize(@activity_view : ActivityView)
    end

    # Presents the overlay / modal.
    def present
      @is_presenting = true
      @activity_view.is_presented = true
    end

    # Dismisses the overlay / modal.
    def dismiss
      @is_presenting = false
      @activity_view.is_presented = false
      @activity_view.on_cancel.try(&.call)
    end
  end
end
