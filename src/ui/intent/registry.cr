# Phase 10B.0 — UI::Intent::Registry
#
# Class-scoped storage for Tier 2 intent routing. Per
# architecture-decisions.md Decision 4 #3, override storage is class-
# scoped on `UI::App` / `UI::Screen` classes (NOT instance fields on
# Screen). Screens are constructed fresh on every render — instance
# fields would not survive a rebuild. Class-level entries do.
#
# The registry holds three logical tables:
#
#   1. **defaults**  — per-intent default widget per platform
#                      (`{intent_id, platform} => UI::View.class`).
#   2. **app overrides** — explicit per-app overrides
#                      (`{app_class, intent_id} => UI::View.class`).
#   3. **screen overrides** — explicit per-screen overrides
#                      (`{screen_class, intent_id} => UI::View.class`).
#
# Lookup precedence on `resolve_for(intent_id, context)`:
#
#   screen override (if screen class known) → app override → default.
#
# Capability validation runs at REGISTRATION time, not resolve time.
# When an override is registered, the registry walks the widget's
# declared capabilities (recorded via the `declares_capabilities` macro
# on the widget class) and asserts that they cover the intent's
# required capability set. Mismatches raise
# `UI::Intent::IncompatibleOverride` immediately so the author sees
# the problem at app-boot, not at first render.
#
# # Why a registry rather than instance state?
#
# Screens are stateless render functions per Phase 8B's contract — a
# fresh `Screen.new` is built per request / per mount. Instance fields
# would be born nil on every rebuild and never see the override calls
# made at app-boot. Class-level storage survives rebuilds because the
# class object itself is process-lifetime.

require "../../asset_pipeline/amber_integration"
require "../../asset_pipeline/native_app"

module UI
  module Intent
    # Raised by `UI::Intent.resolve` when no widget is registered for
    # the requested `(intent_id, platform)` combination. The error
    # message names the intent and platform so authors can install the
    # missing override without spelunking.
    #
    # Phase 10B.0 deliberately surfaces missing widgets as a typed
    # exception rather than a silent placeholder fallback (per
    # architecture-decisions.md Decision 4 #5). 10B.1a removes the
    # error for `:swipe_actions` by introducing `UI::InlineActionRow`.
    class UnresolvableDefault < Exception
    end

    # Raised by `UI::Intent::Registry.register_*_override` when the
    # override widget's `declares_capabilities` block does not cover
    # the intent's required capability set. Names the missing
    # capability + the widget + the intent so the author sees the
    # exact mismatch at registration time.
    class IncompatibleOverride < Exception
    end

    module Registry
      # Default widget per (intent_id, platform) pair. Populated by
      # `register_default(intent_id, platform, widget_class)`.
      @@defaults = {} of Tuple(Symbol, Symbol) => UI::View.class

      # App-scoped override. Populated by
      # `register_app_override(app_class, intent_id, widget_class)`.
      @@app_overrides = {} of Tuple(UI::App.class, Symbol) => UI::View.class

      # Screen-scoped override. Populated by
      # `register_screen_override(screen_class, intent_id, widget_class)`.
      @@screen_overrides = {} of Tuple(UI::Screen.class, Symbol) => UI::View.class

      # Per-widget declared capabilities — populated by the
      # `declares_capabilities` macro on the widget class. Key is the
      # widget class + the intent_id it claims to satisfy. Value is
      # the capability bag (Hash(Symbol, Bool | Symbol)) the widget
      # claims to support.
      @@widget_capabilities = {} of Tuple(UI::View.class, Symbol) => Hash(Symbol, Bool | Symbol)

      # Per-intent required capability set. Populated by
      # `declare_intent_capabilities(intent_id, required)`. Used at
      # override-registration time to check the override widget covers
      # every required capability.
      @@intent_required_capabilities = {} of Symbol => Hash(Symbol, Bool | Symbol)

      # ------------------------------------------------------------------
      # Reset hook for specs.
      # ------------------------------------------------------------------

      # Clear every table. SPEC-ONLY. Production code should never call
      # this — it strands every registered default, override, and
      # capability declaration.
      def self.reset_for_spec : Nil
        @@defaults.clear
        @@app_overrides.clear
        @@screen_overrides.clear
        @@widget_capabilities.clear
        @@intent_required_capabilities.clear
        nil
      end

      # ------------------------------------------------------------------
      # Defaults table.
      # ------------------------------------------------------------------

      # Register the default widget for a given (intent_id, platform)
      # pair. Idempotent — re-registering replaces the prior entry
      # without warning (the resolver is data-driven; the latest
      # declaration wins).
      def self.register_default(
        intent_id : Symbol,
        platform : Symbol,
        widget_class : UI::View.class,
      ) : Nil
        @@defaults[{intent_id, platform}] = widget_class
        nil
      end

      # Lookup the default widget for the (intent_id, platform) pair.
      # Returns `nil` if no default is registered.
      def self.default_for(intent_id : Symbol, platform : Symbol) : (UI::View.class)?
        @@defaults[{intent_id, platform}]?
      end

      # ------------------------------------------------------------------
      # Intent capability requirements.
      # ------------------------------------------------------------------

      # Declare the capability set required by `intent_id`. Called once
      # at framework boot per intent. Subsequent `register_*_override`
      # calls validate the override widget covers this required set.
      #
      # `:partial` capability semantics — a required capability of
      # value `true` requires the override to declare `true` (NOT
      # `false`, NOT `:partial`). A required value of `:partial` is
      # satisfied by any of `true`, `:partial`. A required value of
      # `false` is satisfied by anything (no constraint).
      def self.declare_intent_capabilities(
        intent_id : Symbol,
        required : Hash(Symbol, Bool | Symbol),
      ) : Nil
        @@intent_required_capabilities[intent_id] = required
        nil
      end

      # Returns the recorded required capabilities for `intent_id`, or
      # an empty hash if none declared.
      def self.required_capabilities_for(intent_id : Symbol) : Hash(Symbol, Bool | Symbol)
        @@intent_required_capabilities[intent_id]? || {} of Symbol => Bool | Symbol
      end

      # ------------------------------------------------------------------
      # Widget capability declarations.
      # ------------------------------------------------------------------

      # Record that `widget_class` declares the given capability bag for
      # `intent_id`. Called from the `declares_capabilities` macro on
      # the widget class.
      def self.declare_widget_capabilities(
        widget_class : UI::View.class,
        intent_id : Symbol,
        capabilities : Hash(Symbol, Bool | Symbol),
      ) : Nil
        @@widget_capabilities[{widget_class, intent_id}] = capabilities
        nil
      end

      # Lookup the declared capabilities for a (widget_class, intent_id)
      # pair. Returns nil if the widget declared none.
      def self.declared_capabilities_for(
        widget_class : UI::View.class,
        intent_id : Symbol,
      ) : Hash(Symbol, Bool | Symbol)?
        @@widget_capabilities[{widget_class, intent_id}]?
      end

      # ------------------------------------------------------------------
      # Override registration.
      # ------------------------------------------------------------------

      # Register an app-scoped override. Validates capabilities first;
      # raises `IncompatibleOverride` if the widget does not declare
      # enough capability coverage for the intent. After the validation
      # pass, the override is written to the table — subsequent
      # `resolve_for` calls see it.
      def self.register_app_override(
        app_class : UI::App.class,
        intent_id : Symbol,
        widget_class : UI::View.class,
      ) : Nil
        validate_override_capabilities(widget_class, intent_id, scope: "app #{app_class}")
        @@app_overrides[{app_class, intent_id}] = widget_class
        nil
      end

      # Register a screen-scoped override. Same validation contract as
      # `register_app_override` — runs at registration time.
      def self.register_screen_override(
        screen_class : UI::Screen.class,
        intent_id : Symbol,
        widget_class : UI::View.class,
      ) : Nil
        validate_override_capabilities(widget_class, intent_id, scope: "screen #{screen_class}")
        @@screen_overrides[{screen_class, intent_id}] = widget_class
        nil
      end

      # Walk the intent's required capability set and assert the widget
      # declared each capability with a compatible value. Raises
      # `IncompatibleOverride` on the first missing capability, naming
      # the widget + intent + missing capability key so the author can
      # add the declaration on the widget's class body.
      private def self.validate_override_capabilities(
        widget_class : UI::View.class,
        intent_id : Symbol,
        scope : String,
      ) : Nil
        required = required_capabilities_for(intent_id)
        return if required.empty?

        declared = declared_capabilities_for(widget_class, intent_id) || {} of Symbol => Bool | Symbol

        required.each do |key, required_value|
          case required_value
          when true
            unless declared[key]? == true
              raise IncompatibleOverride.new(
                "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                "is missing required capability `#{key}` (intent requires `true`, " \
                "widget declared #{declared[key]?.inspect}). " \
                "Add `#{key}: true` to the widget's `declares_capabilities` block, " \
                "or pick a different widget."
              )
            end
          when :partial
            value = declared[key]?
            unless value == true || value == :partial
              raise IncompatibleOverride.new(
                "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                "is missing required capability `#{key}` (intent requires `:partial` or `true`, " \
                "widget declared #{value.inspect}). " \
                "Add `#{key}: :partial` (or `true`) to the widget's `declares_capabilities` block."
              )
            end
          else
            # Symbol other than :partial — exact match required.
            unless declared[key]? == required_value
              raise IncompatibleOverride.new(
                "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                "is missing required capability `#{key}` (intent requires #{required_value.inspect}, " \
                "widget declared #{declared[key]?.inspect})."
              )
            end
          end
        end

        nil
      end

      # ------------------------------------------------------------------
      # Resolution.
      # ------------------------------------------------------------------

      # Resolve the widget class for `intent_id` given `context`.
      #
      # The screen-class hint is optional. When the caller knows which
      # `UI::Screen` subclass is currently building, the resolver
      # checks screen-scoped overrides first. Without that hint, the
      # resolver skips the screen tier (it cannot infer which screen
      # is current from the context alone — `ScreenContext::Native`
      # does not carry a screen ref).
      #
      # Returns nil if neither override nor default is registered. The
      # public `UI::Intent.resolve` wraps this and raises
      # `UnresolvableDefault` when nil.
      def self.resolve_for(
        intent_id : Symbol,
        context : UI::ScreenContext,
        screen_class : (UI::Screen.class)? = nil,
      ) : (UI::View.class)?
        if screen_class && (hit = @@screen_overrides[{screen_class, intent_id}]?)
          return hit
        end

        @@app_overrides.each do |key, widget|
          return widget if key[1] == intent_id
        end

        default_for(intent_id, context.platform)
      end

      # Spec-only accessor: returns the count of app overrides registered
      # against `app_class` for `intent_id`. Helps tests assert
      # registration happened without exposing the raw class-var.
      def self.app_override_count_for(app_class : UI::App.class, intent_id : Symbol) : Int32
        @@app_overrides.count { |k, _| k[0] == app_class && k[1] == intent_id }
      end

      # Spec-only accessor: returns the count of screen overrides registered
      # against `screen_class` for `intent_id`.
      def self.screen_override_count_for(screen_class : UI::Screen.class, intent_id : Symbol) : Int32
        @@screen_overrides.count { |k, _| k[0] == screen_class && k[1] == intent_id }
      end
    end
  end
end
