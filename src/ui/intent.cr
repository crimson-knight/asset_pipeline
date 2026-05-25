# Phase 10B.0 — UI::Intent resolver entry point.
#
# `UI::Intent.resolve(intent_id, context)` is the public API screens
# call when they want the platform-appropriate concrete widget for an
# intent. It threads `context.platform` into the registry's lookup, and
# raises `UI::Intent::UnresolvableDefault` if neither an override nor a
# default is registered.
#
# Example call-site (proven to compile against `UI::SwipeActionRow`):
#
#     row_class = UI::Intent.resolve(:swipe_actions, context)
#     row = row_class.new(content_view)
#
# # Per architecture-decisions.md Decision 4 #6
#
# When no default widget is registered for the given (intent_id,
# platform), the resolver raises an explicit `UnresolvableDefault`
# exception. There is NO silent placeholder fallback — masking a
# missing widget would hide the gap and ship broken visuals. Authors
# must either install a `UI::App.override_intent` for the platform or
# wait for the framework slice that ships the missing default
# (e.g. 10B.1a installs `UI::InlineActionRow` for macOS / web_wide).
#
# # Per architecture-decisions.md Decision 4 #5 — capability validation
#
# Capability validation does not run at `resolve` time. It runs at
# `register_*_override` time inside `UI::Intent::Registry`. This keeps
# the resolver hot path cheap (a single hash lookup per call) and
# surfaces capability mismatches at app boot — not at first user tap.

require "./intent/registry"
require "../asset_pipeline/amber_integration"

module UI
  module Intent
    # Public resolver entry point. Looks up the registered widget for
    # `intent_id` given `context.platform`. Raises
    # `UI::Intent::UnresolvableDefault` if no widget is registered.
    #
    # `screen_class:` is an optional kwarg. Passing a `UI::Screen`
    # subclass enables the screen-scoped override tier — useful for
    # callers that know which screen is building (e.g. a screen
    # calling `UI::Intent.resolve` from its own `build` method).
    # Without the hint, the resolver skips screen-scoped overrides.
    def self.resolve(
      intent_id : Symbol,
      context : UI::ScreenContext,
      screen_class : UI::Screen.class? = nil,
    ) : UI::View.class
      widget = UI::Intent::Registry.resolve_for(intent_id, context, screen_class: screen_class)
      return widget if widget

      raise UnresolvableDefault.new(
        "No widget registered for intent #{intent_id.inspect} on platform #{context.platform.inspect}. " \
        "Either install a default via `UI::Intent::Registry.register_default(#{intent_id.inspect}, #{context.platform.inspect}, ...)` " \
        "OR register an override via `UI::App.override_intent(#{intent_id.inspect}, MyWidget)`. " \
        "If you're hitting this on macOS or web_wide for `:swipe_actions`, the missing widget is " \
        "`UI::InlineActionRow` (Phase 10B.1a target)."
      )
    end
  end
end
