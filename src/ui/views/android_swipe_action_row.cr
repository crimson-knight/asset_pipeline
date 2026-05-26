# Android-platform default for the `:swipe_actions` intent. The Phase
# 10B.1c Tier 2 widget that closes the `UnresolvableDefault` gap for
# `:android` left open by 10B.0 + 10B.1a.
#
# # Why a NEW widget rather than extending `UI::SwipeActionRow`?
#
# Material Design 3 (M3) has a first-class swipe-to-dismiss component
# (`androidx.compose.material3.SwipeToDismissBox`) intended for
# Mail-style row actions. The library North Star is "honest defaults
# that map to the platform-idiomatic widget" — so on Android the
# `:swipe_actions` resolver should ultimately route to that M3 widget,
# NOT to the iOS `UI::SwipeActionRow` (whose renderer-side mapping
# targets SwiftUI `.swipeActions`) and NOT to the macOS / desktop-web
# `UI::InlineActionRow` (whose render strategy is HIG-driven "no
# gesture, inline buttons").
#
# A separate widget keeps capability declarations honest per platform:
# when the JNI bridge gains a Compose-interop surface, only
# `UI::AndroidSwipeActionRow` flips from `:partial` to full gesture
# support, and the other two widgets stay accurate for their own
# native targets.
#
# # Current implementation status
#
# Today the Android renderer is the View-system bridge (LinearLayout +
# MaterialButton + MaterialCardView via `android_view_new` /
# `android_view_new_themed`). It has NO Jetpack Compose interop, so
# `M3.SwipeToDismissBox` is unreachable from the current bridge. Until
# a Compose-host surface lands in `src/ui/native/android_bridge.c`,
# the renderer falls back to a horizontal `LinearLayout` of
# (leading actions, content, trailing actions) — same shape as
# `UI::InlineActionRow`'s Android dispatch. The capability declaration
# below reflects the fallback reality, not the eventual M3 contract.
#
# See `docs/initiative-cross-platform-ui/handoff/phase-10-b-1c-close.md`
# for the JNI-blocker write-up.
#
# # Reactivity contract
#
# Following `[[reactivity-is-table-stakes]]`: `leading_actions` and
# `trailing_actions` are mutable arrays. Mutating them between renders
# MUST surface in the next render — the Android renderer rebuilds the
# child list from the live arrays every visit, and the web/macOS/iOS
# fallback paths do the same. Spec coverage in
# `spec/web/ui/views/android_swipe_action_row_spec.cr` includes the
# mutate-and-re-render assertion.

require "../view"
require "./swipe_action_row" # for SwipeAction value type

module UI
  # A list row whose trailing-action set is rendered with the Android-
  # idiomatic chrome. The `:android` default for the `:swipe_actions`
  # intent (Phase 10B.1c).
  #
  # On `:android` (native renderer with `-Dandroid`): the row's
  # `leading_actions` + `content` + `trailing_actions` are laid out in
  # a horizontal `LinearLayout` with `MaterialButton` siblings around
  # the content view. The aspirational mapping is
  # `androidx.compose.material3.SwipeToDismissBox`; that mapping is
  # gated behind a Compose-host JNI bridge that does not yet exist.
  #
  # On every other platform (`:macos`, `:ios`, `:ipados`, `:web_wide`,
  # `:web_narrow`): rendered as visible inline buttons — same shape as
  # `UI::InlineActionRow`. This means an app that registers
  # `UI::AndroidSwipeActionRow` as an override on a non-Android
  # platform gets HIG-accurate fallback chrome, not a stub.
  #
  # Shares the `UI::SwipeAction` value type with `UI::SwipeActionRow`
  # and `UI::InlineActionRow` so authors can swap widgets without
  # rewriting their action lists.
  #
  # Example:
  #   row = UI::AndroidSwipeActionRow.new(content_view)
  #   row.trailing_actions = [
  #     UI::SwipeAction.new("Archive") { archive(item) },
  #     UI::SwipeAction.new("Delete", role: :destructive) { delete(item) },
  #   ]
  class AndroidSwipeActionRow < View
    # Phase 10B.1c — Tier 2 capability declaration. Mirrors the
    # `:swipe_actions` capability set declared by `UI::SwipeActionRow`
    # and `UI::InlineActionRow` so the resolver treats the three
    # widgets as interchangeable on their respective platforms.
    #
    # `supports_role_destructive: :partial` reflects the LinearLayout
    # fallback (button color tints destructive role but no
    # SwipeToDismiss reveal-and-confirm flow); flip to `true` once the
    # Compose bridge lands and the renderer can route through
    # `SwipeToDismissBox` with role-aware confirm semantics.
    declares_capabilities :swipe_actions, {
      supports_edge_trailing:    true,
      supports_role_default:     true,
      supports_role_destructive: :partial,
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
  end
end
