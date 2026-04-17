module UI
  # A small app-shell model for building top-level menus.
  #
  # The native menu bar chrome still belongs to AppKit/UIKit. This object keeps
  # the menu structure and intent in Crystal until the bridge lands.
  class MenuBar
    record Menu,
      title : String,
      menu : ContextMenu

    property menus : Array(Menu) = [] of Menu
    property is_installed : Bool = false

    def initialize
    end

    def add_menu(title : String, menu : ContextMenu = ContextMenu.new, &block : ContextMenu -> Nil) : ContextMenu
      yield menu
      @menus << Menu.new(title: title, menu: menu)
      menu
    end

    def add_menu(title : String, menu : ContextMenu = ContextMenu.new) : ContextMenu
      @menus << Menu.new(title: title, menu: menu)
      menu
    end

    def remove_menu(title : String) : Bool
      before = @menus.size
      @menus.reject! { |entry| entry.title == title }
      before != @menus.size
    end

    def clear : Nil
      @menus.clear
    end

    def install : Bool
      {% if flag?(:darwin) %}
        @is_installed = true
        true
      {% else %}
        false
      {% end %}
    end

    def uninstall : Nil
      @is_installed = false
    end
  end
end
