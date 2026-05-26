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
require "./intent/dispatch_result"
require "./intent/platform_feature_binding"
require "./intent/class_c_registry"
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
    # ------------------------------------------------------------------
    # Phase 10B.3.0 — Class C dispatch entry point.
    # ------------------------------------------------------------------

    # Dispatch a Class C intent. Looks up the
    # `PlatformFeatureBinding` registered for `intent_id`, picks the
    # platform lambda matching `UI::Environment.platform`, and invokes
    # it with `args`.
    #
    # # Return contract
    #
    # Returns a `DispatchResult`:
    #
    #   * `DispatchResult.success`           — the platform lambda
    #     completed without raising.
    #   * `DispatchResult.unsupported(why)`  — no binding registered,
    #     OR the binding does not cover the current platform, OR the
    #     binding's `api_capability_check` returned false.
    #   * `DispatchResult.failed(reason)`    — the platform lambda
    #     raised; `reason` is the exception message.
    #
    # Class C dispatch is fire-and-forget by contract — the result is
    # informational. Callers that need result data wire it through a
    # callback inside `args` (e.g. a file-picker binding takes an
    # `on_pick:` symbol identifier; the binding fires a callback
    # registered with `UI::Intent::CallbackRegistry`). The substrate
    # itself returns no payload.
    #
    # # args shape
    #
    # `args` is `Hash(Symbol, String)` — the lowest-common-denominator
    # shape that crosses JNI / objc bridge boundaries safely. Native
    # bindings parse the string keys inside the platform lambda.
    # Callers spell the args as
    # `UI::Intent.dispatch(:hello_world_alert, {message: "hi"})`; the
    # convenience `dispatch(intent_id, **kwargs)` form is documented
    # in the close handoff but deferred — Crystal does not support
    # `**kwargs : Hash(Symbol, String)` without macro gymnastics.
    # Convenience overload — accepts kwargs and packs them into the
    # `Hash(Symbol, String)` form the substrate uses. Keyword values
    # may be any type that supports `to_s`; the conversion happens
    # here so bindings can rely on string args downstream. Call-sites
    # can spell:
    #
    #     UI::Intent.dispatch(:hello_world_alert, message: "hi")
    #
    # in place of the more verbose Hash-literal form.
    def self.dispatch(intent_id : Symbol, **kwargs) : DispatchResult
      args = {} of Symbol => String
      kwargs.each do |k, v|
        args[k] = v.to_s
      end
      dispatch(intent_id, args)
    end

    def self.dispatch(
      intent_id : Symbol,
      args : Hash(Symbol, String) = {} of Symbol => String,
    ) : DispatchResult
      binding = UI::Intent::ClassCRegistry.binding_for(intent_id)
      unless binding
        return DispatchResult.unsupported(
          "No Class C binding registered for intent #{intent_id.inspect}. " \
          "Bindings are installed by `UI::Intent::ClassCBootstrap` at framework " \
          "load — if you expected this intent to be wired, confirm the bootstrap " \
          "file is required and the binding hasn't been gated out by a missing " \
          "compile-time flag."
        )
      end

      platform = UI::Environment.platform
      unless binding.supports?(platform)
        return DispatchResult.unsupported(
          "Intent #{intent_id.inspect} has a binding registered, but the binding " \
          "does not cover platform #{platform.inspect} (or its api_capability_check " \
          "returned false). Either extend the binding's `platforms` map to include " \
          "#{platform.inspect}, or fall back to a platform-appropriate UI " \
          "(e.g. degrade to a copy-link when share isn't available)."
        )
      end

      proc = binding.platform_proc(platform)
      unless proc
        # Defensive — supports? returned true, so the proc must exist;
        # but the typechecker can't prove that without re-reading the
        # Hash. The early return keeps the exception path honest.
        return DispatchResult.unsupported(
          "Intent #{intent_id.inspect} binding claimed support for platform " \
          "#{platform.inspect} but no proc was found in the platforms map. " \
          "This is a substrate bug — please file an issue."
        )
      end

      begin
        proc.call(args)
        DispatchResult.success
      rescue ex : Exception
        DispatchResult.failed(
          "Intent #{intent_id.inspect} on platform #{platform.inspect} raised " \
          "#{ex.class}: #{ex.message}"
        )
      end
    end

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
