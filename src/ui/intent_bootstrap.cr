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
      # Phase 10D — re-callable bootstrap. The original module-body
      # statements only execute at module-load. On iOS, the
      # `[[crystal-ios-class-init-gap]]` (see
      # `project_crystal_ios_class_init_gap` memory) hides `_main` so
      # the module-body never runs and `UI::Intent::Registry`'s class-
      # var literal defaults stay uninitialised. The iOS bridge
      # (`samples/.../ios/bridge.cr#initialize_runtime`) calls
      # `UI::Intent::Bootstrap.install` explicitly to re-run the
      # registrations after `Thread.init` / `Fiber.init` /
      # `Crystal::Once.init`. Idempotent — repeat calls overwrite the
      # same entries.
      def self.install : Nil
        # Phase 10D — iOS class-init gap recovery: also re-run the
        # per-widget `declares_capabilities` writes the
        # `declares_capabilities` macro emits as class-load side
        # effects. The macro compiles to a named class method per
        # `(widget, intent)` pair so the registration is reachable
        # post-load. The names follow the macro template
        # `_declare_capabilities_for_intent_<intent_id>`.
        UI::SwipeActionRow._declare_capabilities_for_intent_swipe_actions
        UI::InlineActionRow._declare_capabilities_for_intent_swipe_actions
        UI::AndroidSwipeActionRow._declare_capabilities_for_intent_swipe_actions

        # ----- Intent required capability declarations -----
        UI::Intent::Registry.declare_intent_capabilities(:swipe_actions, {
          :supports_edge_trailing => true,
          :supports_role_default  => true,
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
        UI::Intent::Registry.register_default(:swipe_actions, :ios, UI::SwipeActionRow)
        UI::Intent::Registry.register_default(:swipe_actions, :ipados, UI::SwipeActionRow)
        UI::Intent::Registry.register_default(:swipe_actions, :web_narrow, UI::SwipeActionRow)
        UI::Intent::Registry.register_default(:swipe_actions, :macos, UI::InlineActionRow)
        UI::Intent::Registry.register_default(:swipe_actions, :web_wide, UI::InlineActionRow)
        UI::Intent::Registry.register_default(:swipe_actions, :android, UI::AndroidSwipeActionRow)
        nil
      end

      # ----- Module-load side effect.
      #
      # This invokes `install` so the framework's defaults are present
      # in every Crystal target whose `_main` runs (web, macOS,
      # Android host). The iOS bridge calls `install` explicitly after
      # the runtime bootstrap.
      install
    end
  end
end
