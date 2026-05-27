# Phase 10B.3.0 — UI::SystemAction::Registry
#
# Process-global registry of Class C `PlatformBinding`s.
# Parallel to `UI::WidgetRoute::Registry` (Class A widget routing), but
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

require "./platform_binding"

module UI
  module SystemAction
    # Singleton registry of Class C bindings. The class itself is the
    # API — no instances are constructed (the `@@table` class-var is
    # the only state, and survives the process lifetime).
    module Registry
      # Registered bindings keyed by `intent_id`. Populated by
      # `register(binding)`.
      #
      # Phase 10D — iOS class-init gap (see
      # `project_crystal_ios_class_init_gap` memory): the literal
      # initializer is skipped when `_main` is hidden for Swift @main,
      # so the table stays as a nil pointer. The `_table` helper
      # lazy-allocates on first read.
      @@table : Hash(Symbol, PlatformBinding)? = nil

      protected def self._table : Hash(Symbol, PlatformBinding)
        @@table ||= {} of Symbol => PlatformBinding
      end

      # ------------------------------------------------------------------
      # Mutation.
      # ------------------------------------------------------------------

      def self.register(binding : PlatformBinding) : Nil
        _table[binding.intent_id] = binding
        nil
      end

      def self.reset_for_spec : Nil
        _table.clear
        nil
      end

      # ------------------------------------------------------------------
      # Lookup.
      # ------------------------------------------------------------------

      def self.binding_for(intent_id : Symbol) : PlatformBinding?
        _table[intent_id]?
      end

      def self.supports?(intent_id : Symbol, platform : Symbol) : Bool
        binding = _table[intent_id]?
        return false unless binding
        binding.supports?(platform)
      end

      def self.registered_count : Int32
        _table.size
      end

      def self.registered_intents : Array(Symbol)
        _table.keys.sort_by(&.to_s)
      end
    end
  end
end
