# List row with edge-swipe revealed actions (leading / trailing).
# Part of the asset_pipeline cross-platform UI::View catalog.

require "../view"

# Top-level namespace for the asset_pipeline cross-platform UI system.
module UI
  # A single swipe action attached to a SwipeActionRow.
  #
  # On iOS / mobile-web: revealed by swiping the row horizontally.
  # On macOS / desktop-web: rendered inline as a visible trailing button.
  #
  # `role` accepts `:default`, `:destructive`, `:cancel`. The renderer maps
  # destructive to the platform-native danger tint (red on iOS / macOS /
  # web via `--ap-color-danger-text`).
  #
  # `icon` is the SF Symbol name on iOS / macOS, ignored elsewhere.
  #
  # `on_tap` is the callback fired when the user activates the action.
  # On iOS / macOS it's registered through the existing Phase 3
  # CallbackRegistry so the Crystal Proc isn't GC'd while native code
  # holds a function pointer to it.
  class SwipeAction
    # Caption / accessibility label rendered alongside the control.
    property label : String
    # Semantic role (e.g. `:primary`, `:destructive`, `:cancel`).
    property role : Symbol
    # Optional icon shown next to the title. Native: SF Symbol name; web: icon class or URL.
    property icon : String?
    # Invoked when the user taps / clicks the control.
    property on_tap : Proc(Nil)?

    # Optional route id the web renderer wires to a client-side
    # UIRouteHost.push() invocation. The static-site web target
    # cannot invoke Crystal Procs client-side, so demos that need
    # runtime swipe-button interactivity supply this string.
    property on_tap_route : String?

    # Phase 10D-polish iter 2 (B-LIST-SWIPE-TINT) — semantic tint
    # override. When nil, the SwiftKit facade falls back to the
    # role-derived default (red for destructive, system blue for
    # trailing default, system green for leading default). Set this
    # to `:blue`, `:green`, `:orange`, `:red`, `:purple`, `:yellow`,
    # `:pink`, or `:gray` to override; the iOS renderer maps these to
    # the matching SwiftUI Color.
    property tint : Symbol?

    # Phase 10D-polish iter 2 (B-LIST-SWIPE-LABEL-STYLE) — controls
    # which of the (label, icon) pair the tile renders.
    # `:auto` (default) — facade infers from which fields are set.
    # `:icon` — icon only; the title becomes accessibilityLabel.
    # `:title` — title only; icon is dropped.
    # `:title_and_icon` — render both (SF Symbols Label style).
    property label_style : Symbol = :auto

    def initialize(
      @label : String,
      @on_tap : Proc(Nil)? = nil,
      @role : Symbol = :default,
      @icon : String? = nil,
      @on_tap_route : String? = nil,
      @tint : Symbol? = nil,
      @label_style : Symbol = :auto,
    )
    end
  end

  # A list row with optional leading + trailing swipe actions.
  #
  # On iOS / UIKit: SwiftUI `.swipeActions(edge: .trailing) { ... }` and
  #                 `.swipeActions(edge: .leading) { ... }` modifiers.
  # On macOS / AppKit: visible HStack of trailing buttons (HIG — macOS
  #                    doesn't have swipe-to-reveal; an explicit row
  #                    affordance is the idiomatic equivalent).
  # On web desktop:    visible HStack of trailing buttons (same as macOS).
  # On web mobile:     touch-event handler that translates the row on
  #                    touchmove and reveals the trailing-actions panel.
  #
  # The `content` view is the primary row content (typically an HStack
  # with a label + meta info). Actions are flat lists; the renderer
  # builds platform-appropriate chrome around them.
  #
  # Example:
  #   row = UI::SwipeActionRow.new(content_view)
  #   row.trailing_actions = [
  #     UI::SwipeAction.new("Edit") { open_editor(item) },
  #     UI::SwipeAction.new("Delete", role: :destructive) { delete(item) },
  #   ]
  class SwipeActionRow < View
    # Phase 10B.1b — Tier 2 capability declaration, platform-honest.
    # Each capability uses a platform-keyed `Hash(Symbol, Bool)` whose
    # entries reflect what the *renderer* for that platform actually
    # backs today (audit citations in
    # `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`):
    #
    # * `supports_edge_trailing` — iOS uses `make_swipe_reveal_row` to
    #   wire a trailing-only swipe; macOS and web emit inline trailing
    #   buttons. Android `visit(SwipeActionRow)` is a stub.
    # * `supports_edge_leading` — Phase 10D-refocus enabled iOS / iPadOS
    #   via the new `APSKSwipeActionRowFacade` (SwiftUI
    #   `.swipeActions(edge: .leading)`). macOS still routes through
    #   `UI::InlineActionRow` by intent registry default. Web supports
    #   leading via inline buttons. Android remains a stub.
    # * `supports_role_default` — true wherever the widget renders at
    #   all (no role-specific styling needed).
    # * `supports_role_destructive` — iOS routes the role through
    #   SwiftKit's `APSKButtonOverrides`; web emits a `.--destructive`
    #   CSS class; the macOS AppKit visit never reads `action.role`
    #   (no destructive tint).
    #
    # Validated by `UI::WidgetRoute::Registry` whenever an app or screen
    # registers `UI::SwipeActionRow` as an override, and at resolve
    # time when `UI::WidgetRoute.resolve(..., capabilities_required: ...)`
    # is called.
    declares_capabilities :swipe_actions, {
      supports_edge_trailing: {
        ios:        true,
        ipados:     true,
        macos:      true,
        web_wide:   true,
        web_narrow: true,
        android:    false,
      },
      supports_edge_leading: {
        ios:        true,
        ipados:     true,
        macos:      false,
        web_wide:   true,
        web_narrow: true,
        android:    false,
      },
      supports_role_default: {
        ios:        true,
        ipados:     true,
        macos:      true,
        web_wide:   true,
        web_narrow: true,
        android:    false,
      },
      supports_role_destructive: {
        ios:        true,
        ipados:     true,
        macos:      false,
        web_wide:   true,
        web_narrow: true,
        android:    false,
      },
    }

    # Child view rendered inside this container.
    property content : View
    # Actions revealed by a leading-edge swipe.
    property leading_actions : Array(SwipeAction)
    # Actions revealed by a trailing-edge swipe.
    property trailing_actions : Array(SwipeAction)

    # Mobile-web breakpoint: viewports below this width get touch-swipe
    # chrome; viewports at/above this width get visible trailing
    # buttons. Defaults to 768px (tablet-portrait boundary).
    property mobile_breakpoint_px : Int32 = 768

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
