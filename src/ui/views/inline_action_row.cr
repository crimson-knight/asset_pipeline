# Inline trailing-action row. The macOS + web_wide default for the
# `:swipe_actions` intent.
#
# Per HIG, macOS has no swipe-to-reveal gesture; the idiomatic
# equivalent for the iOS Mail-style swipe row is a list row with the
# trailing affordances rendered inline as visible buttons (the same
# pattern NSTableView row actions and Finder list-row hover affordances
# follow). Desktop-web shares that conclusion: a wide-viewport mouse-
# driven row should always present its actions visibly.
#
# `UI::InlineActionRow` is the Phase 10B.1a Tier 2 widget that backs
# the `:swipe_actions` intent on `:macos` + `:web_wide`. It shares the
# `UI::SwipeAction` value type with `UI::SwipeActionRow`; the only
# difference between the two widgets is the gesture model — actions
# are always visible inline buttons here.
#
# Example:
#   row = UI::InlineActionRow.new(content_view)
#   row.trailing_actions = [
#     UI::SwipeAction.new("Edit") { open_editor(item) },
#     UI::SwipeAction.new("Delete", role: :destructive) { delete(item) },
#   ]
#
# Capability declaration matches `UI::SwipeActionRow` so the resolver
# treats the two as interchangeable on the platforms each backs.

require "../view"
require "./swipe_action_row" # for SwipeAction value type

module UI
  # A list row with leading / trailing actions rendered inline as
  # visible buttons. The macOS + web_wide default for the
  # `:swipe_actions` intent.
  #
  # Unlike `UI::SwipeActionRow`, this row has no gesture-driven reveal:
  # actions are always visible, sitting next to the row content in a
  # horizontal stack. That is the HIG-correct macOS pattern and the
  # desktop-web convention.
  class InlineActionRow < View
    # Phase 10B.1b — Tier 2 capability declaration, platform-honest.
    # Inline rendering is symmetric (leading + content + trailing) on
    # every renderer that backs the widget, so `supports_edge_leading`
    # and `supports_edge_trailing` track together. Audit citations in
    # `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`:
    #
    # * iOS + Android + web all dispatch action buttons through the
    #   `UI::Button` visit with `role: action.role`, so destructive
    #   tint flows through automatically.
    # * macOS AppKit visit emits `NSButton` siblings with `setTitle:`
    #   only and never reads `action.role` — no destructive tint
    #   today. The capability is honestly `macos: false` until the
    #   AppKit button-role facade lands (separate phase).
    declares_capabilities :swipe_actions, {
      supports_edge_trailing: {
        ios:        true,
        ipados:     true,
        macos:      true,
        web_wide:   true,
        web_narrow: true,
        android:    true,
      },
      supports_edge_leading: {
        ios:        true,
        ipados:     true,
        macos:      true,
        web_wide:   true,
        web_narrow: true,
        android:    true,
      },
      supports_role_default: {
        ios:        true,
        ipados:     true,
        macos:      true,
        web_wide:   true,
        web_narrow: true,
        android:    true,
      },
      supports_role_destructive: {
        ios:        true,
        ipados:     true,
        macos:      false,
        web_wide:   true,
        web_narrow: true,
        android:    true,
      },
    }

    property content : View
    property leading_actions : Array(SwipeAction)
    property trailing_actions : Array(SwipeAction)

    def initialize(@content : View)
      @leading_actions = [] of SwipeAction
      @trailing_actions = [] of SwipeAction
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end

    # Phase 10B.2a — default AX role: `:list_item`.
    def default_accessibility_role : Symbol?
      :list_item
    end
  end
end
