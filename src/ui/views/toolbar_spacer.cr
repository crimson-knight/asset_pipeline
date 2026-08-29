# Toolbar spacer — a fixed or flexible-width spacer between toolbar
# items. Used to push items to the leading / trailing edge, or to add
# explicit visual breathing room between item clusters.
#
# Per the Phase 9 intent catalog (`:toolbar_spacer`):
#   - SwiftUI:   `ToolbarSpacer` (iOS 17+)
#   - UIKit:     `UIBarButtonItem.fixedSpace` / `flexibleSpace`
#   - AppKit:    `NSToolbarItem.Identifier.flexibleSpace`
#   - Android:   `Spacer` between actions
#   - Web:       Flex spacer (`flex: 1` for flexible; fixed width box
#                for fixed-size variant)
#
# `UI::ToolbarSpacer` is the Phase 10B.4 widget backing the intent.

require "../view"

module UI
  # ToolbarSpacer — A spacer between toolbar items. Fixed-width when
  # `fixed_size` is set; otherwise flexible (consumes all remaining
  # horizontal space, pushing neighbouring items to the edges).
  #
  # Usage:
  #   spacer = UI::ToolbarSpacer.new            # flexible
  #   spacer = UI::ToolbarSpacer.new(16.0)      # fixed 16pt
  #
  # Like `UI::Spacer` for stacks, a flexible toolbar spacer between
  # two toolbar items causes the items to "push apart." Multiple
  # flexible spacers share remaining space evenly.
  #
  # Renderer mapping:
  #   - iOS 17+ / iPadOS: `ToolbarSpacer(.flexible)` /
  #                       `.fixed(<size>)` via SwiftKit facade in a
  #                       follow-up phase. Current fallback: a
  #                       UIView with `flex` constraint.
  #   - macOS:            `NSToolbarItem.flexibleSpace` /
  #                       `NSToolbarItem.space`. Current fallback:
  #                       an NSView with horizontal CHCR low so the
  #                       stack stretches it.
  #   - web:              `<div>` with `flex: 1 1 auto` (flexible)
  #                       or `flex: 0 0 <size>px` (fixed).
  #   - Android:          `Space` view between MaterialButtons; for
  #                       flexible spacers, weight=1 on the LinearLayout
  #                       child.
  class ToolbarSpacer < View
    # Fixed pixel / point size. When nil the spacer is flexible
    # (consumes all remaining space). When set, the spacer occupies
    # exactly the given width.
    property fixed_size : Float64? = nil

    def initialize(@fixed_size : Float64? = nil)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Whether this is a flexible (vs fixed) spacer. Convenience getter
    # mirroring the SwiftUI `ToolbarSpacer(.flexible)` /
    # `ToolbarSpacer(.fixed(_:))` API split.
    def flexible? : Bool
      @fixed_size.nil?
    end

    # Phase 10B.2a — A spacer carries no semantics; renderers emit
    # `role="none"` (or aria-hidden) so the screen-reader cursor
    # skips over it.
    def default_accessibility_role : Symbol?
      :none
    end

    # Phase 10B.2b — A spacer is decorative chrome (web emits
    # `aria-hidden="true"`); it must never enter the keyboard tab
    # order. Hard-set the default to false so the `effective_focusable`
    # resolver agrees with the rendered ARIA contract.
    def default_focusable : Bool
      false
    end
  end
end
