# Tier-3 complication with a cross-platform fallback rendering on non-watchOS
# targets. Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"
require "./vstack"
require "./label"
require "./card"

{% if flag?(:watchos) %}
  require "./complication"
{% end %}

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # Cross-platform companion to the watchOS-only UI::Complication.
  #
  # On -Dwatchos: delegates to a held UI::Complication so the WatchKit renderer
  # produces the native WidgetKit accessory complication.
  #
  # On every other target: renders a credible card-style PREVIEW of the
  # complication content (a labelled Card wrapping the content subtree) by
  # COMPOSING existing views and delegating `accept` to the composed tree — so
  # no renderer needs a bespoke `visit(ComplicationWithWebFallback)` method.
  class ComplicationWithWebFallback < View
    # Stable identity for the complication kind (e.g. :next_todo).
    property kind : Symbol
    # WidgetKit accessory family the complication renders as on watchOS.
    property family : ComplicationFamily
    # The content subtree shown by the complication / its preview.
    property content : View

    {% if flag?(:watchos) %}
      @inner : UI::Complication

      def initialize(
        @kind : Symbol,
        @content : View,
        @family : ComplicationFamily = ComplicationFamily::AccessoryRectangular,
      )
        @inner = UI::Complication.new(@kind, @content, @family)
      end

      def accept(visitor : PlatformVisitor)
        @inner.accept(visitor)
      end
    {% else %}
      def initialize(
        @kind : Symbol,
        @content : View,
        @family : ComplicationFamily = ComplicationFamily::AccessoryRectangular,
      )
      end

      # Compose a labelled Card preview of the complication content and delegate
      # to it. No bespoke visitor method required — this renders on web / macOS /
      # iOS / Android via the existing Card + VStack + Label visits.
      def accept(visitor : PlatformVisitor)
        preview = UI::VStack.new(spacing: 4.0)
        caption = UI::Label.new("Complication · #{@family}")
        # Preserve identity on the caption Label, which reliably surfaces a
        # test_id as an AX identifier (decorative containers like Card do not),
        # so the fallback is discoverable / labelled the same as the
        # complication it stands in for.
        if t = test_id
          caption.test_id = t
        end
        if a = accessibility_label
          caption.accessibility_label = a
        end
        preview << caption.as(UI::View)
        preview << @content
        card = UI::Card.new(preview.as(UI::View))
        card.accept(visitor)
      end
    {% end %}
  end
end
