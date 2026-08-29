# Scrolling vertical list of rows with native idiomatic chrome.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"
require "./swipe_action_row" # for SwipeAction value type (Phase 10D-final)

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # A scrollable list of items with optional sections.
  class ListView < View
    # A section in the list
    record Section,
      header : String? = nil,
      items : Array(View) = [] of View,
      footer : String? = nil

    # List sections (use a single section for flat lists)
    property sections : Array(Section) = [] of Section

    # Visual style
    property style : ListStyle = ListStyle::Plain

    # Layout mode: List (vertical rows) or Grid (multi-column grid).
    # Grid maps to NSCollectionView on macOS and UICollectionView on iOS.
    # Default is List for backward compatibility.
    property layout : ListLayout = ListLayout::List

    # Number of columns when layout == ListLayout::Grid.
    # Ignored in List layout mode. Typical HIG photo grids use 2–4 columns.
    property columns : Int32 = 3

    # Gap between grid cells in points (both horizontal and vertical).
    # Ignored in List layout mode.
    property item_spacing : Float64 = 8.0

    # Whether to show separators between items
    property shows_separators : Bool = true

    # Callback when an item is tapped (receives section index, item index)
    property on_item_tap : Proc(Int32, Int32, Nil)? = nil

    # Phase 10D-final — flat-index tap callback. Called with the
    # absolute row index across all sections when the user taps anywhere
    # on a row. Matches the SwiftUI `.onTapGesture` per-row pattern.
    # Coexists with `on_item_tap` (section-index variant) for callers
    # that prefer the sectioned semantics.
    property on_row_tap : Proc(Int32, Nil)? = nil

    # Phase 10D-final — drag-reorder callback. Called with
    # (from_index, to_index) absolute row indexes when the user
    # long-press-drags a row to a new position. Maps to SwiftUI's
    # `.onMove(perform:)` modifier on the inner ForEach.
    property on_move : Proc(Int32, Int32, Nil)? = nil

    # Phase 10D-final — per-row leading swipe actions. Receives the
    # absolute row index and returns the action tiles revealed by a
    # leading-edge swipe (left-to-right). Empty array → no leading
    # swipe affordance on that row.
    property leading_swipe_actions : Proc(Int32, Array(SwipeAction))? = nil

    # Phase 10D-final — per-row trailing swipe actions. Receives the
    # absolute row index and returns the action tiles revealed by a
    # trailing-edge swipe (right-to-left). The first action in the
    # returned array is SwiftUI's full-swipe target on iOS.
    property trailing_swipe_actions : Proc(Int32, Array(SwipeAction))? = nil

    # Phase 10D-polish A4 — default horizontal row inset (leading +
    # trailing). 16pt matches the iOS Mail / Reminders / Settings
    # idiomatic row edge inset and is now the widget default so
    # consumers don't have to pad the surrounding stack. The renderer
    # applies this via SwiftUI's `.listRowInsets(...)` modifier on iOS;
    # AppKit and web renderers honor it via their own row-padding paths.
    # Set to nil to delegate to the platform-native default.
    property content_inset_horizontal : Float64? = 16.0

    # Phase 10D-polish A3 — row-removal animation duration (in seconds).
    # When set, the iOS facade animates row removal with
    # `withAnimation(.easeInOut(duration: ...))` so deletes / Mark Done
    # collapse smoothly instead of vanishing. Default 0.4s matches the
    # owner-aligned 400-500ms range. Set to 0.0 to disable.
    property row_removal_duration_seconds : Float64 = 0.4

    # Phase 10D-polish A2 — show a `line.3.horizontal` drag affordance
    # on the trailing edge of every row when `on_move != nil`. Default
    # true so any list that wires reorder gets the visual anchor for
    # free. Set to false on lists where you've wired `on_move` but
    # don't want the system grip indicator (e.g. a custom drag handle).
    property shows_drag_handle : Bool = true

    def initialize(@sections : Array(Section) = [] of Section, @style : ListStyle = ListStyle::Plain, @layout : ListLayout = ListLayout::List, @columns : Int32 = 3)
    end

    # Convenience: create a flat list from an array of views
    def self.flat(items : Array(View), style : ListStyle = ListStyle::Plain) : ListView
      list = new(style: style)
      list.sections = [Section.new(items: items)]
      list
    end

    # Total number of items across all sections
    def item_count : Int32
      sections.sum(&.items.size)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:list`.
    def default_accessibility_role : Symbol?
      :list
    end
  end
end
