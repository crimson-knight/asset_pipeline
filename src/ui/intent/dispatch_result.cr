# Phase 10B.3.0 — UI::Intent::DispatchResult
#
# Return type for `UI::Intent.dispatch(intent_id, **args)`. Class C
# intents (cross-platform-bridged features) are fire-and-forget by
# contract — they invoke a native side-effect (share sheet, alert,
# clipboard write) and do not produce a `UI::View`. But callers still
# need to know whether the dispatch found a binding, whether the
# platform actually supports the feature, and (if the binding failed)
# why — without paying the cost of an exception on the happy path.
#
# # Three states
#
# * `Success`    — the platform-specific block ran without raising.
# * `Unsupported`— no `PlatformFeatureBinding` is registered for the
#                  intent, OR the binding exists but the running
#                  platform is not covered by its `platforms` map, OR
#                  the binding's `api_capability_check` returned
#                  `false` for the current environment.
# * `Failed`     — the binding ran but raised an exception. The
#                  `reason` carries the exception message so the
#                  caller can log / surface it.
#
# # Why a struct hierarchy, not an enum
#
# `Failed` carries a `reason` payload; an `enum` would force callers
# to read the reason from a separate accessor with implicit nil
# semantics. A small `Union(Success | Unsupported | Failed)` keeps the
# payload attached to the only variant that carries one.
#
# # Why not raise on Unsupported?
#
# Class C intents are intentionally optional — a screen that calls
# `UI::Intent.dispatch(:share_link, ...)` on a platform that doesn't
# back sharing should degrade gracefully (e.g. fall back to a copy
# link). Raising would force every call-site into a `begin/rescue`
# block and discourage feature-detection. `feature_supported?` exists
# for callers that want to check first; `Unsupported` exists for
# callers that prefer to ask forgiveness rather than permission.

module UI
  module Intent
    # Tagged union for Class C dispatch outcomes. Construct via the
    # class methods (`DispatchResult.success`, `.unsupported`,
    # `.failed(reason)`) — instances are tiny value-style records and
    # safe to discard.
    abstract struct DispatchResult
      # Successful dispatch — the platform binding's block ran without
      # raising. No payload (Class C is fire-and-forget; if a feature
      # needs to return data, it does so via a callback, not the
      # dispatch result).
      struct Success < DispatchResult
        def success? : Bool
          true
        end

        def unsupported? : Bool
          false
        end

        def failed? : Bool
          false
        end

        def reason : String?
          nil
        end
      end

      # No binding covers the current `(intent_id, platform)` pair —
      # either the intent is not registered, the platform is not in the
      # binding's `platforms` map, or the binding's capability check
      # returned `false`. The `detail` describes which of the three
      # reasons applied so logs / debug output can disambiguate.
      struct Unsupported < DispatchResult
        getter detail : String

        def initialize(@detail : String)
        end

        def success? : Bool
          false
        end

        def unsupported? : Bool
          true
        end

        def failed? : Bool
          false
        end

        def reason : String?
          @detail
        end
      end

      # The platform-specific block raised. `reason` carries the
      # exception message. Class C bindings are user-defined, so any
      # exception type may flow through; the substrate normalises to
      # the message string.
      struct Failed < DispatchResult
        getter reason : String

        def initialize(@reason : String)
        end

        def success? : Bool
          false
        end

        def unsupported? : Bool
          false
        end

        def failed? : Bool
          true
        end
      end

      # Convenience constructors. Most call-sites read clearer with
      # `DispatchResult.success` than `DispatchResult::Success.new`.
      def self.success : DispatchResult
        Success.new
      end

      def self.unsupported(detail : String) : DispatchResult
        Unsupported.new(detail)
      end

      def self.failed(reason : String) : DispatchResult
        Failed.new(reason)
      end

      # All variants implement the three predicates and `reason`.
      # The abstract base declares the API surface.
      abstract def success? : Bool
      abstract def unsupported? : Bool
      abstract def failed? : Bool
      abstract def reason : String?
    end
  end
end
