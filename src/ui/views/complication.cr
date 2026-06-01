# watchOS complication — a glanceable watch-face / smart-stack surface.
# Part of the asset_pipeline cross-platform UI::View catalog.
#
# Tier 3 — watchOS-only. A complication has no honest analog on phone / desktop
# / web (it is a watch-face widget). Naming this class without -Dwatchos is a
# compile-time error (see _gate_stubs/complication.cr). For a cross-platform
# instance that renders a credible fallback everywhere, use
# UI::ComplicationWithWebFallback.
#
# Render path (Phase 12): the WatchKit renderer maps this to a WidgetKit
# `accessory*` complication, driven by the App-Group JSON snapshot bridge.
# See docs/initiative-cross-platform-ui/phases/phase-12-watchos.md.

require "../view"

{% if flag?(:watchos) %}
  # Top-level namespace for the asset_pipeline cross-platform UI system.
  module UI
    # WidgetKit complication families available on watchOS. Universal data
    # (also defined on non-watchOS builds so cross-platform code can annotate a
    # ComplicationWithWebFallback without -Dwatchos).
    enum ComplicationFamily
      AccessoryCircular
      AccessoryRectangular
      AccessoryInline
      AccessoryCorner
    end

    # Tier 3 — watchOS-only complication. Mirrors UI::HomeScreenWidget
    # (kind / family / content) with the watch family set.
    class Complication < View
      # Stable identity for the complication kind (e.g. :next_todo).
      property kind : Symbol
      # WidgetKit accessory family this complication renders as.
      property family : ComplicationFamily
      # The (SwiftUI-only-renderable) content subtree.
      property content : View

      def initialize(
        @kind : Symbol,
        @content : View,
        @family : ComplicationFamily = ComplicationFamily::AccessoryRectangular,
      )
      end

      def accept(visitor : PlatformVisitor)
        visitor.visit(self)
      end
    end
  end
{% else %}
  # ComplicationFamily is universal data (no platform behavior); expose it so
  # non-watchOS code can still annotate ComplicationWithWebFallback instances.
  # The gated stub for the Complication class itself lives in
  # _gate_stubs/complication.cr.
  module UI
    enum ComplicationFamily
      AccessoryCircular
      AccessoryRectangular
      AccessoryInline
      AccessoryCorner
    end
  end

  require "./_gate_stubs/complication"
{% end %}
