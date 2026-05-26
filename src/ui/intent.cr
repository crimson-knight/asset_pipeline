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
#
# # Iter-9 (Codex Finding 2) — signature now matches the brief
#
# The shipped signature carries `capabilities_required :
# Hash(Symbol, Bool)? = nil` per `brief-10-b-0.md` line 62. The earlier
# implementer drift toward `screen_class:` was retired — the active
# screen class travels on `ScreenContext.active_screen_class` instead
# (added by iter-9). `capabilities_required` enables migration /
# soft-fallback callers that want the resolver to assert the chosen
# widget covers a specific subset of capabilities at lookup time
# (e.g. an analytics overlay that resolves `:swipe_actions` and
# requires `supports_role_destructive` to be true before mounting).
# When a required capability is missing, the resolver raises
# `UnresolvableDefault` rather than returning a degraded widget.

require "./intent/registry"
require "../asset_pipeline/amber_integration"

module UI
  module Intent
    # Public resolver entry point. Looks up the registered widget for
    # `intent_id` given `context.platform`. Raises
    # `UI::Intent::UnresolvableDefault` if no widget is registered.
    #
    # `capabilities_required:` is an optional kwarg. When provided, the
    # resolver asserts the resolved widget's declared capabilities
    # (recorded via `declares_capabilities`) cover every required key
    # before returning. A mismatch surfaces as `UnresolvableDefault`
    # — the caller gets the same actionable error path as a
    # missing-default lookup, with the diff capability named in the
    # message. The hot path (no kwarg) skips this check entirely.
    #
    # The active screen class — used to consult the screen-tier
    # override table — is read from `context.active_screen_class` (a
    # property on `ScreenContext` added in iter-9). Screens that want
    # screen-scoped overrides set `ctx.active_screen_class = self.class`
    # in their `build` body, or rely on the host (dispatcher /
    # `compute_screen_html`) to set it when it builds the context.
    def self.resolve(
      intent_id : Symbol,
      context : UI::ScreenContext,
      capabilities_required : Hash(Symbol, Bool)? = nil,
    ) : UI::View.class
      widget = UI::Intent::Registry.resolve_for(intent_id, context)
      if widget
        if capabilities_required && (missing = first_missing_capability(widget, intent_id, capabilities_required, context.platform))
          raise UnresolvableDefault.new(
            "Resolved widget #{widget} for intent #{intent_id.inspect} on platform " \
            "#{context.platform.inspect} is missing required capability `#{missing}`. " \
            "Pick a widget that declares `#{missing}: true` for #{context.platform.inspect}, " \
            "or drop the `capabilities_required:` kwarg if the caller can tolerate the gap."
          )
        end
        return widget
      end

      raise UnresolvableDefault.new(
        "No widget registered for intent #{intent_id.inspect} on platform #{context.platform.inspect}. " \
        "Either install a default via `UI::Intent::Registry.register_default(#{intent_id.inspect}, #{context.platform.inspect}, ...)` " \
        "OR register an override via `UI::App.override_intent(#{intent_id.inspect}, MyWidget)`. " \
        "If you're hitting this on macOS or web_wide for `:swipe_actions`, the missing widget is " \
        "`UI::InlineActionRow` (Phase 10B.1a target)."
      )
    end

    # Returns the first capability key in `required` that the widget
    # does NOT back for `intent_id` on the given `platform`. Returns
    # nil if the widget covers everything required. Used by `.resolve`
    # for the `capabilities_required:` kwarg path.
    #
    # # Phase 10B.1b — platform-aware lookup
    #
    # The widget's declared capability value can now be a platform-
    # keyed `Hash(Symbol, Bool)`. We delegate to
    # `UI::Intent::Registry.platform_supported?` so a declaration like
    # `supports_role_destructive: {ios: true, macos: false}` correctly
    # passes when `context.platform == :ios` and fails when
    # `context.platform == :macos`.
    private def self.first_missing_capability(
      widget_class : UI::View.class,
      intent_id : Symbol,
      required : Hash(Symbol, Bool),
      platform : Symbol,
    ) : Symbol?
      declared = UI::Intent::Registry.declared_capabilities_for(widget_class, intent_id) ||
                 ({} of Symbol => UI::Intent::Registry::CapabilityValue)
      required.each do |key, needed|
        next unless needed
        value = declared[key]?
        return key unless UI::Intent::Registry.platform_supported?(value, platform)
      end
      nil
    end
  end
end
