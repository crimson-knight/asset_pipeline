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
      # The `:swipe_actions` requirement set per
      # `docs/initiative-cross-platform-ui/architecture/intent-routing-candidates.md`
      # (post-Phase-10-pre.1 honesty pass). Only the capabilities that
      # are actually backed by source today, plus `supports_role_default`
      # which is universally backed.
      UI::Intent::Registry.declare_intent_capabilities(:swipe_actions, {
        :supports_edge_trailing    => true,
        :supports_role_default     => true,
        :supports_role_destructive => :partial,
      } of Symbol => Bool | Symbol)

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
      # :android  — NO default; Phase 10B.1c will install UI::AndroidSwipeActionRow.
    end
  end
end
