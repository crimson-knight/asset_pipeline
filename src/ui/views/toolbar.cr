# Top-of-screen toolbar container hosting buttons and other tools.
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Toolbar — Top-of-screen toolbar container hosting buttons and other tools.
  class Toolbar < View
    record ToolbarItem,
      id : String = "",
      label : String = "",
      icon : String? = nil,
      action : Proc(Nil)? = nil

    # Items rendered by the control.
    property items : Array(ToolbarItem) = [] of ToolbarItem
    # Primary text shown on the control.
    property title : String? = nil
    # Boolean toggle.
    property shows_title : Bool = true

    # Phase 5 v2 — Apple semantic material override. nil = HIG-canonical
    # default :system_resolved (SwiftUI's `.toolbarBackground(.bar, for:)`
    # handles toolbar chrome).
    property material_semantic : Symbol? = nil

    def initialize(@title : String? = nil)
    end

    def add_item(id : String, label : String, icon : String? = nil, &block : -> Nil)
      @items << ToolbarItem.new(id: id, label: label, icon: icon, action: block)
    end

    def add_item(id : String, label : String, icon : String? = nil)
      @items << ToolbarItem.new(id: id, label: label, icon: icon)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:toolbar`.
    def default_accessibility_role : Symbol?
      :toolbar
    end
  end
end
