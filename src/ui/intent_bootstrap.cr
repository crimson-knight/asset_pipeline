# Phase 10B.0 — Intent default + capability bootstrap.
#
# This file is loaded by `src/ui.cr` AFTER `views/*` so that every
# Tier 2 widget class (with its `declares_capabilities` macro call) has
# already executed and written its declared-capability bag into the
# registry.
#
# This file:
#
#   1. Declares the intent-level required-capability sets that
#      `UI::Intent::Registry.register_*_override` validates against.
#   2. Installs platform-default widgets for each intent on the
#      platforms that have a working implementation today.
#
# Per architecture-decisions.md Decision 4 #5, platforms WITHOUT a
# working widget (e.g. macOS / web_wide for `:swipe_actions`) get NO
# default — `UI::Intent.resolve` raises `UnresolvableDefault` to make
# the gap loud. Subsequent slices (10B.1a, 10B.1c) close those gaps.
#
# # Why a separate file rather than inline at the bottom of `intent.cr`?
#
# `intent.cr` is loaded BEFORE `views/*`. If we put the bootstrap there,
# the `UI::SwipeActionRow` class wouldn't exist yet, and the
# `register_default(:swipe_actions, :ios, UI::SwipeActionRow)` call
# would fail to resolve the constant. By isolating bootstrap into its
# own file ordered AFTER `views/*`, the references are valid.

require "./intent"

module UI
  module Intent
    module Bootstrap
      # ----- Intent required capability declarations -----
      #
      # The `:swipe_actions` requirement set per the platform-honesty
      # audit in
      # `docs/initiative-cross-platform-ui/architecture/swipe-actions-capability-audit.md`
      # (Phase 10B.1b). The previous declaration coded
      # `supports_role_destructive => :partial`, which collapsed the
      # AppKit "no destructive tint" gap and the Android stub into a
      # single fuzzy symbol. 10B.1b replaces that with a platform-keyed
      # `Hash(Symbol, Bool)` so the registry can detect honesty
      # mismatches per platform at registration time and at resolve
      # time (when `capabilities_required:` is passed).
      UI::Intent::Registry.declare_intent_capabilities(:swipe_actions, {
        :supports_edge_trailing => true,
        :supports_role_default  => true,
        # Destructive tint demanded on iOS / iPadOS / web; not demanded
        # on macOS until the AppKit button-role facade lands and not on
        # Android until 10B.1c installs `UI::AndroidSwipeActionRow`.
        :supports_role_destructive => {
          :ios        => true,
          :ipados     => true,
          :macos      => false,
          :web_wide   => true,
          :web_narrow => true,
          :android    => false,
        } of Symbol => Bool,
      } of Symbol => UI::Intent::Registry::CapabilityValue)

      # ----- Platform default widgets -----
      #
      # `:swipe_actions` defaults — only the platforms whose
      # implementations actually work today (per
      # `intent-routing-candidates.md` defaults block + the audit in
      # `intent-backlog.md`). Other platforms intentionally lack a
      # default so `UnresolvableDefault` fires.
      UI::Intent::Registry.register_default(:swipe_actions, :ios, UI::SwipeActionRow)
      UI::Intent::Registry.register_default(:swipe_actions, :ipados, UI::SwipeActionRow)
      UI::Intent::Registry.register_default(:swipe_actions, :web_narrow, UI::SwipeActionRow)
      # Phase 10B.1a — macOS + web_wide back the `:swipe_actions` intent
      # with `UI::InlineActionRow` (HIG: no swipe-to-reveal on the Mac;
      # desktop-web mirrors the convention with visible inline buttons).
      UI::Intent::Registry.register_default(:swipe_actions, :macos, UI::InlineActionRow)
      UI::Intent::Registry.register_default(:swipe_actions, :web_wide, UI::InlineActionRow)
      # Phase 10B.1c — Android backs `:swipe_actions` with
      # `UI::AndroidSwipeActionRow`. The aspirational mapping is
      # `androidx.compose.material3.SwipeToDismissBox` but the current
      # JNI bridge is View-system only; the renderer falls back to a
      # horizontal LinearLayout. The capability declaration on the
      # widget reflects the fallback (`supports_role_destructive:
      # :partial`) so registration-time validation stays honest.
      # See `docs/initiative-cross-platform-ui/handoff/phase-10-b-1c-close.md`.
      UI::Intent::Registry.register_default(:swipe_actions, :android, UI::AndroidSwipeActionRow)
    end
  end
end
