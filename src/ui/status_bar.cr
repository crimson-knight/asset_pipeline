module UI
  # A small app-shell model for a macOS status item and its attached menu.
  #
  # The actual `NSStatusItem` chrome remains system-owned; this type simply
  # captures the item's intent until the native bridge exists.
  class StatusBar
    property identifier : String
    property title : String?
    property icon : String?
    property tooltip : String?
    property menu : ContextMenu?
    property is_template_icon : Bool = true
    property is_visible : Bool = true
    property is_installed : Bool = false

    def initialize(@identifier : String = "status-item",
                   @title : String? = nil,
                   @icon : String? = nil,
                   @tooltip : String? = nil,
                   @menu : ContextMenu? = nil)
    end

    def with_menu(menu : ContextMenu = ContextMenu.new, &block : ContextMenu -> Nil) : ContextMenu
      yield menu
      @menu = menu
      menu
    end

    def attach(menu : ContextMenu) : ContextMenu
      @menu = menu
      menu
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
