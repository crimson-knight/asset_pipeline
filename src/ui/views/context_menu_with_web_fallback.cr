require "../view"
{% if flag?(:macos) || flag?(:ios) %}
  require "./context_menu"
{% end %}

module UI
  # Cross-platform companion to the Apple-family-only UI::ContextMenu.
  #
  # On -Dmacos / -Dios: delegates to a held UI::ContextMenu instance, so
  # the native renderer produces the standard NSMenu / UIMenu chrome.
  #
  # On every other target: renders directly. The web visitor produces a
  # role=menu positioned dropdown with arrow-key navigation, escape-to-
  # dismiss, and focus restoration (see context_menu_fallback.js).
  class ContextMenuWithWebFallback < View
    record Item,
      label : String,
      icon : String? = nil,
      is_destructive : Bool = false,
      is_disabled : Bool = false,
      action : Proc(Nil)? = nil

    struct Separator
    end

    alias Entry = Item | Separator

    property items : Array(Entry) = [] of Entry

    {% if flag?(:macos) || flag?(:ios) %}
      @inner : UI::ContextMenu

      def initialize
        @inner = UI::ContextMenu.new
      end

      def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false, &block : -> Nil)
        @items << Item.new(
          label: label, icon: icon,
          is_destructive: is_destructive, is_disabled: is_disabled,
          action: block,
        )
        @inner.add_item(label, icon, is_destructive, is_disabled, &block)
      end

      def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false)
        @items << Item.new(
          label: label, icon: icon,
          is_destructive: is_destructive, is_disabled: is_disabled,
        )
        @inner.add_item(label, icon, is_destructive, is_disabled)
      end

      def add_separator
        @items << Separator.new
        @inner.add_separator
      end

      def accept(visitor : PlatformVisitor)
        @inner.accept(visitor)
      end
    {% else %}
      def initialize
      end

      def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false, &block : -> Nil)
        @items << Item.new(
          label: label, icon: icon,
          is_destructive: is_destructive, is_disabled: is_disabled,
          action: block,
        )
      end

      def add_item(label : String, icon : String? = nil, is_destructive : Bool = false, is_disabled : Bool = false)
        @items << Item.new(
          label: label, icon: icon,
          is_destructive: is_destructive, is_disabled: is_disabled,
        )
      end

      def add_separator
        @items << Separator.new
      end

      def accept(visitor : PlatformVisitor)
        visitor.visit(self)
      end
    {% end %}
  end
end
