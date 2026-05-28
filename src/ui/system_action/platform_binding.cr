# Phase 10B.3.0 — UI::SystemAction::PlatformBinding
#
# Declarative shape that describes how a single Class C intent maps to
# per-platform native APIs. Each Class C feature constructs one
# `PlatformBinding` at bootstrap time and registers it with
# `UI::SystemAction::Registry.register(binding)`.
#
# # Anatomy
#
#     UI::SystemAction::PlatformBinding.new(
#       intent_id: :share_link,
#       api_capability_check: ->(platform : Symbol) { ... },
#       platforms: {
#         ios:        ->(args : Hash(Symbol, String)) { ... },
#         ipados:     ->(args : Hash(Symbol, String)) { ... },
#         macos:      ->(args : Hash(Symbol, String)) { ... },
#         android:    ->(args : Hash(Symbol, String)) { ... },
#         web_wide:   ->(args : Hash(Symbol, String)) { ... },
#         web_narrow: ->(args : Hash(Symbol, String)) { ... },
#       }
#     )
#
# # api_capability_check semantics
#
# Called at dispatch time AND `feature_supported?` time. Receives the
# current platform symbol. Returns `true` when the running build /
# host environment has the underlying API available (e.g. the
# `UserNotifications` framework is linked, `navigator.share` exists
# on the current browser). Bindings whose underlying API is universal
# at their min-deployment target pass `->(_) { true }`.
#
# Default is `->(_) { true }` (no extra capability gate beyond
# platform presence in the `platforms` map) — bindings that gate on
# build-time or browser-level features must opt in.
#
# # args shape
#
# `args` is `Hash(Symbol, String)` — the lowest-common-denominator
# shape that crosses the JNI / objc bridge boundary safely. Bindings
# that need typed payloads (e.g. a `URI` instead of a `String`) parse
# the string inside the platform lambda. We deliberately do NOT type
# `args` as `Hash(Symbol, T)` because every Class C intent has a
# different argument shape — a generic substrate would force a sum
# type on every call-site for negligible gain.
#
# # Why a struct, not a class
#
# Bindings are immutable after registration. A struct keeps the
# substrate allocation-free for the common case (resolve binding ->
# dispatch).

module UI
  module SystemAction
    # Immutable descriptor for one Class C feature's per-platform
    # native mappings. Constructed once at bootstrap, stored in
    # `ClassCRegistry`, looked up by `UI::SystemAction.perform`.
    struct PlatformBinding
      # Alias for the Hash(Symbol, String) args bag every platform
      # lambda receives. Exposed publicly so binding authors can spell
      # the signature without re-typing the generic.
      alias Args = Hash(Symbol, String)

      # Alias for the per-platform implementation lambda. Takes the
      # args bag, performs the side-effect, returns nothing. The
      # dispatcher catches any raise and rolls it into
      # `Result.failed`.
      alias PlatformProc = Args -> Nil

      # Alias for the api-capability check lambda. Takes the current
      # platform symbol; returns `true` when the underlying API is
      # available in this build / browser / host.
      alias CapabilityCheck = Symbol -> Bool

      getter intent_id : Symbol
      getter api_capability_check : CapabilityCheck
      getter platforms : Hash(Symbol, PlatformProc)

      def initialize(
        @intent_id : Symbol,
        @platforms : Hash(Symbol, PlatformProc),
        @api_capability_check : CapabilityCheck = ->(_p : Symbol) { true },
      )
      end

      # Returns true when the binding covers `platform` AND the
      # capability check passes for that platform. Used by both
      # `ClassCRegistry.supports?` and the dispatch path.
      def supports?(platform : Symbol) : Bool
        return false unless @platforms.has_key?(platform)
        @api_capability_check.call(platform)
      end

      # Returns the platform lambda for `platform`, or nil if the
      # binding does not cover that platform.
      def platform_proc(platform : Symbol) : PlatformProc?
        @platforms[platform]?
      end
    end
  end
end
