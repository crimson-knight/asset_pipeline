# Toolbar item group — visually associated cluster of toolbar items
# that belong together (e.g. a [Bold | Italic | Underline] formatting
# group, or a [Cut | Copy | Paste] edit cluster).
#
# Per the Phase 9 intent catalog (`:toolbar_item_group`):
#   - SwiftUI:   `ToolbarItemGroup(placement:content:)`
#   - UIKit:     `UIBarButtonItemGroup`
#   - AppKit:    `NSToolbarItemGroup`
#   - Android:   Visual cluster of action slots in `TopAppBar`
#   - Web:       `<div role="group">` wrapping toolbar buttons
#
# Today `UI::Toolbar` ships flat `add_item(...)`; `UI::ToolbarItemGroup`
# is a parallel construct that an app uses to add a cluster of items
# that visually group together. The group can be placed in a Toolbar's
# `items_groups` array or used as a standalone view that renderers
# treat as an item-cluster fragment.

require "../view"
require "./toolbar"

module UI
  # ToolbarItemGroup — A cluster of toolbar items visually grouped to
  # signal "these belong together." The Phase 10B.4 widget backing the
  # `:toolbar_item_group` intent.
  #
  # The group carries the same `ToolbarItem` value type used by
  # `UI::Toolbar` (the record defined in `toolbar.cr:10-14`) so an item
  # authored against `Toolbar#add_item` can be hoisted into a group
  # without rewriting.
  #
  # Apps may use `UI::ToolbarItemGroup` either:
  #   1. As a standalone view in a non-toolbar surface (renderers emit
  #      a horizontal cluster), or
  #   2. By passing the group's items into a `UI::Toolbar` via
  #      `toolbar.add_group(group)` (the Toolbar visitor walks the
  #      group's items as a contiguous visually-bounded run; the
  #      placement field on Toolbar carries forward unchanged).
  #
  # The Phase 10B.4 visitor-side rendering is path 1 (standalone). The
  # Toolbar host-integration path is tracked under B-011 for follow-up.
  #
  # Renderer mapping:
  #   - iOS / iPadOS: `UIBarButtonItemGroup` via SwiftKit facade in a
  #                   follow-up phase. Current fallback: horizontal
  #                   UIStackView of UIButton siblings with a divider.
  #   - macOS:        `NSToolbarItemGroup` via SwiftKit facade in a
  #                   follow-up phase. Current fallback: horizontal
  #                   NSStackView of NSButton siblings.
  #   - web:          `<div role="group" aria-label="...">` wrapping
  #                   `<button>` siblings. The `aria-label` carries the
  #                   group's `label` so VoiceOver announces the cluster.
  #   - Android:      Horizontal LinearLayout of MaterialButton siblings.
  class ToolbarItemGroup < View
    # The items composing the group. Uses the same `Toolbar::ToolbarItem`
    # record (`src/ui/views/toolbar.cr:10-14`) so items can flow freely
    # between flat toolbars and grouped clusters.
    property items : Array(Toolbar::ToolbarItem) = [] of Toolbar::ToolbarItem

    # Optional human-readable label describing the group's purpose
    # ("Formatting", "Edit", "Playback"). Renderers emit this as the
    # group's `aria-label` / `accessibilityLabel` so the cluster reads
    # as a single semantic unit to assistive tech.
    property label : String? = nil

    # When true, renderers emit a visual divider between the group and
    # neighbouring items (a hairline on web / macOS, a separator on iOS
    # 17+). Default true — groups exist precisely to communicate
    # boundary; suppress via `with_divider = false` when the parent
    # surface already provides spacing.
    property with_divider : Bool = true

    def initialize(@label : String? = nil)
    end

    # Append an item to the group. Mirrors `UI::Toolbar#add_item` so the
    # author-facing API surface is symmetrical.
    def add_item(id : String, label : String, icon : String? = nil, &block : -> Nil)
      @items << Toolbar::ToolbarItem.new(id: id, label: label, icon: icon, action: block)
    end

    def add_item(id : String, label : String, icon : String? = nil)
      @items << Toolbar::ToolbarItem.new(id: id, label: label, icon: icon)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:group`. Web emits
    # `role="group"`; UIKit / AppKit emit no native role (the
    # `accessibility_label` slot carries the group name).
    def default_accessibility_role : Symbol?
      :group
    end
  end
end
