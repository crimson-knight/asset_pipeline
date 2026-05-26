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
      # Phase 10B.1b — type alias for a capability value. A widget
      # capability declaration carries one of:
      #
      #   * `true` / `false` — universal support / no support.
      #   * `:partial` (Symbol) — fuzzy legacy "some platforms,
      #     unspecified." Accepted for back-compat.
      #   * `Hash(Symbol, Bool)` — platform-keyed support map. Keys are
      #     platform symbols (`:ios`, `:ipados`, `:macos`,
      #     `:web_wide`, `:web_narrow`, `:android`); values mark whether
      #     the renderer for that platform actually backs the
      #     capability today.
      #
      # The aliased union type is what every Registry method that
      # accepts a capability bag references, so a single edit here
      # threads the platform-keyed shape through validation,
      # resolution, and declaration storage.
      alias CapabilityValue = Bool | Symbol | Hash(Symbol, Bool)

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
      # the capability bag the widget claims to support.
      @@widget_capabilities = {} of Tuple(UI::View.class, Symbol) => Hash(Symbol, CapabilityValue)

      # Per-intent required capability set. Populated by
      # `declare_intent_capabilities(intent_id, required)`. Used at
      # override-registration time to check the override widget covers
      # every required capability.
      @@intent_required_capabilities = {} of Symbol => Hash(Symbol, CapabilityValue)

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

      # Clear ONLY override tables + defaults (NOT
      # `@@widget_capabilities`, which holds class-static metadata
      # written once at widget class-body load and cannot be
      # re-installed at runtime). Iter-9 added this for specs that
      # need to test the resolver from a clean override state while
      # leaving widget capability declarations intact.
      def self.reset_overrides_for_spec : Nil
        @@defaults.clear
        @@app_overrides.clear
        @@screen_overrides.clear
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
      # # Required-value semantics (Phase 10B.1b)
      #
      # * `true` — override widget must declare `true` OR a platform-
      #   keyed `Hash` that covers every platform where the intent has
      #   a registered default with `true`. `:partial` no longer
      #   satisfies a `true` requirement (10B.1b honesty fix —
      #   `:partial` was previously accepted, collapsing per-platform
      #   gaps into a single fuzzy symbol).
      # * `:partial` — satisfied by any of `true`, `:partial`, or a
      #   `Hash` with at least one `true` cell.
      # * `false` — no constraint.
      # * `Hash(Symbol, Bool)` — platform-keyed requirement. For each
      #   platform the required hash sets to `true`, the widget's
      #   declared value must be `true` for that platform (either
      #   declared as `true` outright, or as a platform-keyed hash with
      #   that key set to `true`).
      def self.declare_intent_capabilities(
        intent_id : Symbol,
        required : Hash(Symbol, CapabilityValue),
      ) : Nil
        @@intent_required_capabilities[intent_id] = required
        nil
      end

      # Returns the recorded required capabilities for `intent_id`, or
      # an empty hash if none declared.
      def self.required_capabilities_for(intent_id : Symbol) : Hash(Symbol, CapabilityValue)
        @@intent_required_capabilities[intent_id]? || {} of Symbol => CapabilityValue
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
        capabilities : Hash(Symbol, CapabilityValue),
      ) : Nil
        @@widget_capabilities[{widget_class, intent_id}] = capabilities
        nil
      end

      # Lookup the declared capabilities for a (widget_class, intent_id)
      # pair. Returns nil if the widget declared none.
      def self.declared_capabilities_for(
        widget_class : UI::View.class,
        intent_id : Symbol,
      ) : Hash(Symbol, CapabilityValue)?
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
      #
      # # Phase 10B.1b — platform-keyed validation
      #
      # When the required value is a `Hash(Symbol, Bool)`, each
      # platform marked `true` in the requirement must be backed by
      # the widget (either declared `true` outright, or declared as a
      # platform-keyed hash with that key set to `true`). When the
      # required value is `true` (universal), the widget's declared
      # platform-keyed hash must cover every platform where the intent
      # has a registered default — otherwise the override would
      # shadow a working default with a widget that silently drops the
      # capability on that platform.
      private def self.validate_override_capabilities(
        widget_class : UI::View.class,
        intent_id : Symbol,
        scope : String,
      ) : Nil
        required = required_capabilities_for(intent_id)
        return if required.empty?

        declared = declared_capabilities_for(widget_class, intent_id) || {} of Symbol => CapabilityValue
        default_platforms = platforms_with_default_for(intent_id)

        required.each do |key, required_value|
          declared_value = declared[key]?

          case required_value
          when true
            validate_universal_requirement(
              widget_class, intent_id, scope,
              key, declared_value, default_platforms,
            )
          when :partial
            unless declared_value == true ||
                   declared_value == :partial ||
                   (declared_value.is_a?(Hash) && declared_value.any? { |_, v| v == true })
              raise IncompatibleOverride.new(
                "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                "is missing required capability `#{key}` (intent requires `:partial` or " \
                "`true`, widget declared #{declared_value.inspect}). " \
                "Add `#{key}: :partial` (or `true`, or a platform-keyed Hash with at " \
                "least one true cell) to the widget's `declares_capabilities` block."
              )
            end
          else
            # Hash (platform-keyed) or Symbol other than :partial.
            if required_value.is_a?(Hash)
              required_value.each do |plat, needed|
                next unless needed
                unless platform_supported?(declared_value, plat)
                  raise IncompatibleOverride.new(
                    "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                    "is missing required capability `#{key}` on platform #{plat.inspect} " \
                    "(intent requires `true` for that platform, widget declared " \
                    "#{describe_platform_support(declared_value, plat)}). " \
                    "Add `#{key}: {#{plat.to_s}: true, ...}` (or `#{key}: true`) to the widget's " \
                    "`declares_capabilities` block, or pick a different widget."
                  )
                end
              end
            else
              unless declared_value == required_value
                raise IncompatibleOverride.new(
                  "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
                  "is missing required capability `#{key}` (intent requires " \
                  "#{required_value.inspect}, widget declared #{declared_value.inspect})."
                )
              end
            end
          end
        end

        nil
      end

      # Validate a universal (`required == true`) capability. The
      # widget must declare `true`, OR a platform-keyed Hash where
      # every platform with a registered default for the intent is
      # backed (`true`). This is what catches the audit-honesty
      # mismatch — declaring `true` while platform renderers silently
      # drop the capability is rejected at registration time when the
      # widget switches to the honest platform-keyed declaration.
      private def self.validate_universal_requirement(
        widget_class : UI::View.class,
        intent_id : Symbol,
        scope : String,
        key : Symbol,
        declared_value,
        default_platforms : Array(Symbol),
      ) : Nil
        return if declared_value == true

        if declared_value.is_a?(Hash)
          # Every platform that has a registered default for the intent
          # must be covered by the override's platform-keyed hash. The
          # override is meant to *replace* the default — silently
          # dropping a capability on a platform the default backed is
          # exactly the regression we want to catch.
          missing = default_platforms.select { |plat| !platform_supported?(declared_value, plat) }
          return if missing.empty?
          raise IncompatibleOverride.new(
            "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
            "claims `#{key}` but the platform-keyed declaration does not back " \
            "every platform with a registered default. " \
            "Missing platforms: #{missing.inspect}. Widget declared " \
            "#{declared_value.inspect}. Add the missing platform keys with `true`, " \
            "or pick a different widget."
          )
        end

        raise IncompatibleOverride.new(
          "Override for #{intent_id.inspect} on #{scope} with #{widget_class} " \
          "is missing required capability `#{key}` (intent requires `true`, " \
          "widget declared #{declared_value.inspect}). " \
          "Add `#{key}: true` (or a platform-keyed Hash covering every default " \
          "platform) to the widget's `declares_capabilities` block, or pick a " \
          "different widget."
        )
      end

      # Returns the sorted unique list of platforms that have a
      # registered default for `intent_id`. Used by the universal
      # requirement validator to determine which platforms an
      # override-widget's platform-keyed declaration must cover.
      protected def self.platforms_with_default_for(intent_id : Symbol) : Array(Symbol)
        @@defaults.compact_map do |k, _|
          k[0] == intent_id ? k[1] : nil
        end.uniq.sort_by(&.to_s)
      end

      # Returns true when `value` claims support for `platform`.
      # Compatible with every CapabilityValue shape:
      #
      #   * `true` — supports everywhere → returns true.
      #   * `false` / `nil` — no support → returns false.
      #   * `:partial` — fuzzy; treated as NOT supported for the
      #     specific-platform query (the caller wanted a precise
      #     answer; `:partial` does not give one).
      #   * `Hash` — returns `hash[platform]? == true`.
      protected def self.platform_supported?(value, platform : Symbol) : Bool
        case value
        when true then true
        when Hash
          value[platform]? == true
        else
          false
        end
      end

      # Human-readable description of the widget's stance on a
      # platform, for diagnostic messages.
      private def self.describe_platform_support(value, platform : Symbol) : String
        case value
        when true then "`true` (universal)"
        when false then "`false`"
        when :partial then "`:partial` (fuzzy)"
        when nil then "nothing (capability not declared)"
        when Hash
          if value.has_key?(platform)
            "`{#{platform.to_s}: #{value[platform]}}`"
          else
            "platform-keyed hash with no entry for #{platform.inspect}"
          end
        else
          value.inspect
        end
      end

      # ------------------------------------------------------------------
      # Resolution.
      # ------------------------------------------------------------------

      # Resolve the widget class for `intent_id` given `context`.
      #
      # The screen-class hint is optional. When the caller knows which
      # `UI::Screen` subclass is currently building, the resolver
      # checks screen-scoped overrides first. Iter-9 (Codex Finding 2):
      # the explicit kwarg is retained for back-compat, but the
      # canonical source is `context.active_screen_class` — the public
      # `UI::Intent.resolve` reads it from there and threads no kwarg.
      # Without either source, the resolver skips the screen tier.
      #
      # The app tier is consulted ONLY when `context.app_class` is set
      # (iter-9, Codex Finding 1). Without an app-class on the context,
      # the resolver cannot tell which app owns this build, so it
      # skips app-tier rather than leaking an override from an
      # unrelated app — overrides keyed by `{app_class, intent_id}`
      # would otherwise be effectively process-global.
      #
      # Returns nil if neither override nor default is registered. The
      # public `UI::Intent.resolve` wraps this and raises
      # `UnresolvableDefault` when nil.
      def self.resolve_for(
        intent_id : Symbol,
        context : UI::ScreenContext,
        screen_class : (UI::Screen.class)? = nil,
      ) : (UI::View.class)?
        # The active screen class is sourced from (in order): the
        # explicit kwarg (back-compat for specs that pass it directly)
        # OR `context.active_screen_class` (iter-9 — the public
        # resolver path always reads it here).
        active_screen = screen_class || context.active_screen_class
        if active_screen && (hit = @@screen_overrides[{active_screen, intent_id}]?)
          return hit
        end

        if (app_class = context.app_class) && (hit = @@app_overrides[{app_class, intent_id}]?)
          return hit
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
