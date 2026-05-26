# Phase 10B.3.0 — UI::Intent::ClassCRegistry
#
# Process-global registry of Class C `PlatformFeatureBinding`s.
# Parallel to `UI::Intent::Registry` (Class A widget routing), but
# with a flat shape — Class C has no override tiers because the
# bindings are framework-owned (a consumer app cannot meaningfully
# substitute a different `:share_link` implementation; the binding
# IS the framework's mapping to UIActivityViewController etc.).
#
# # Storage
#
# A single hash keyed by `intent_id`. Re-registering replaces the
# prior binding — last-wins. Consumers should not call `register`
# more than once for the same intent_id outside of test setup.
#
# # Why no override tiers?
#
# Class A intents (widget routing) need app- and screen-scoped
# overrides because brand designers swap default widgets out for
# branded variants. Class C intents bridge to native system APIs;
# the "implementation" is the framework binding itself. If a consumer
# app needs a different behaviour (e.g. log every share before
# dispatching), they wrap the dispatch call-site, not the binding.
#
# # Spec hooks
#
# `reset_for_spec` clears every registered binding. The framework
# bootstrap (`class_c_bootstrap.cr`) reinstalls the framework
# defaults; spec suites that test the registry directly call this
# from a `before_each` block to start from a clean state.

require "./platform_feature_binding"

module UI
  module Intent
    # Singleton registry of Class C bindings. The class itself is the
    # API — no instances are constructed (the `@@table` class-var is
    # the only state, and survives the process lifetime).
    module ClassCRegistry
      # Registered bindings keyed by `intent_id`. Populated by
      # `register(binding)`.
      @@table = {} of Symbol => PlatformFeatureBinding

      # ------------------------------------------------------------------
      # Mutation.
      # ------------------------------------------------------------------

      # Register `binding` under its `intent_id`. Idempotent —
      # re-registering replaces the prior entry without warning
      # (matches `UI::Intent::Registry.register_default` semantics).
      def self.register(binding : PlatformFeatureBinding) : Nil
        @@table[binding.intent_id] = binding
        nil
      end

      # SPEC-ONLY — clear every binding. Production code does not call
      # this; the bootstrap installs framework bindings once at load.
      def self.reset_for_spec : Nil
        @@table.clear
        nil
      end

      # ------------------------------------------------------------------
      # Lookup.
      # ------------------------------------------------------------------

      # Returns the binding registered for `intent_id`, or nil.
      def self.binding_for(intent_id : Symbol) : PlatformFeatureBinding?
        @@table[intent_id]?
      end

      # Returns `true` when a binding exists for `intent_id` AND the
      # binding covers `platform` AND the binding's capability check
      # returns true for `platform`.
      #
      # Used by `UI::Environment.feature_supported?` AND the dispatch
      # path before invoking the platform lambda. Cheaper than
      # constructing a `DispatchResult.unsupported` and walking three
      # branches at every call-site.
      def self.supports?(intent_id : Symbol, platform : Symbol) : Bool
        binding = @@table[intent_id]?
        return false unless binding
        binding.supports?(platform)
      end

      # Returns the count of registered Class C intents. Spec hook.
      def self.registered_count : Int32
        @@table.size
      end

      # Returns the sorted list of registered Class C intent ids.
      # Used by introspection / docs generation.
      def self.registered_intents : Array(Symbol)
        @@table.keys.sort_by(&.to_s)
      end
    end
  end
end
