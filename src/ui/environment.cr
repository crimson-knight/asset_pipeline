# Phase 10B.3.0 — UI::Environment
#
# Process-level platform + capability surface that Class C intents
# read at dispatch time. Sits beside `UI::ScreenContext`: a context
# carries per-build state (form values, navigation, design tokens,
# active screen class), while `Environment` carries
# process-lifetime state that does not change between builds (the
# running platform identity, the set of native features the build was
# linked against).
#
# # Why a separate object rather than reading from ScreenContext
#
# `UI::Intent.dispatch(:hello_world_alert, message: "hi")` is a
# fire-and-forget side-effect that any code can call — including code
# that does not have a `ScreenContext` in scope (a callback fired by a
# native button tap, a timer expiry, an async network response). The
# resolver path for Class A intents always runs inside a `build(ctx)`
# call and naturally has a context to read; Class C is broader.
# Tying dispatch to context would force every Class C call-site to
# thread a context object through layers that do not otherwise need
# one.
#
# # Platform detection
#
# The runtime platform is sourced from Crystal's compile-time
# `flag?(:macos | :ios | :ipados | :android)` markers. The Web build
# (no flag) falls through to `:web_wide` as the conservative default;
# consumer apps that want viewport-aware behaviour
# (`:web_narrow`) call `UI::Environment.set_platform(:web_narrow)`
# from their JS bridge after viewport detection.
#
# # feature_supported?
#
# `UI::Environment.feature_supported?(intent_id)` consults the
# `ClassCRegistry` to determine whether a binding exists for the
# current platform AND whether the binding's
# `api_capability_check` returns `true` for the current environment.
# Web bindings use this to surface "Web Share API on Chrome 90+ /
# Safari 14+ / Firefox" feature-detection without baking a UA sniff
# into every call-site.

module UI
  # Process-level environment surface. Class C intents read this at
  # dispatch time to decide which platform branch of their
  # `PlatformFeatureBinding` to execute (or whether to fail with
  # `DispatchResult.unsupported`).
  module Environment
    # The platform identity for the current process. Set once by the
    # bootstrap path (`set_platform`) or read from the compile-time
    # `flag?` defaults. Reads in production are constant-time after
    # the first call.
    #
    # The supported values mirror `ScreenContext#platform` and
    # `UI::Intent::Registry` lookups:
    #   `:ios`, `:ipados`, `:macos`, `:android`, `:web_wide`, `:web_narrow`.
    @@platform : Symbol = begin
      {% if flag?(:macos) %}
        :macos
      {% elsif flag?(:ipados) %}
        :ipados
      {% elsif flag?(:ios) %}
        :ios
      {% elsif flag?(:android) %}
        :android
      {% else %}
        :web_wide
      {% end %}
    end

    # Returns the current platform identity. The same symbol passed to
    # `UI::Intent::Registry.register_default` and used as the key in a
    # `PlatformFeatureBinding#platforms` map.
    def self.platform : Symbol
      @@platform
    end

    # Override the platform at runtime. Used by:
    #
    #   * Web hosts that detect a narrow viewport client-side and
    #     want subsequent `UI::Intent.dispatch` calls to pick up
    #     `:web_narrow` bindings.
    #   * Tests that need to exercise multiple platform branches
    #     against a single binding registration.
    #
    # Production native apps do NOT call this — the compile-time
    # flag is authoritative.
    def self.set_platform(platform : Symbol) : Nil
      @@platform = platform
      nil
    end

    # SPEC-ONLY — restore the compile-time default platform. Pairs
    # with `set_platform` calls in test blocks.
    def self.reset_platform_for_spec : Nil
      @@platform = {% if flag?(:macos) %}
                     :macos
                   {% elsif flag?(:ipados) %}
                     :ipados
                   {% elsif flag?(:ios) %}
                     :ios
                   {% elsif flag?(:android) %}
                     :android
                   {% else %}
                     :web_wide
                   {% end %}
      nil
    end

    # Returns `true` when a Class C `PlatformFeatureBinding` exists
    # for `intent_id` on the current platform AND the binding's
    # `api_capability_check` lambda returns `true` for the current
    # environment.
    #
    # Use this to feature-detect before rendering UI that would
    # otherwise call `UI::Intent.dispatch(intent_id, ...)`. The Web
    # build uses it to gate Share-API-dependent UI off browsers that
    # lack `navigator.share`; the native builds use it to surface
    # availability of optional frameworks (e.g. UserNotifications on
    # older minimum-deployment targets).
    #
    # NOTE: `feature_supported?` is a NON-mutating check — it does
    # not execute the binding's platform block. It only asks
    # "would dispatch succeed (modulo runtime exceptions)?"
    def self.feature_supported?(intent_id : Symbol) : Bool
      UI::Intent::ClassCRegistry.supports?(intent_id, @@platform)
    end
  end
end
