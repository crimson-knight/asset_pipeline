# Phase 8B — Native UI::App declarative screen registry.
#
# An app defines its top-level structure by subclassing `UI::App` and
# declaring its screens. Each `screen :route_id, FooController` macro
# call registers a route_id → (controller, screen) mapping that the
# `UI::ActionDispatcher` consults when an action resolves to a route.
#
# Example:
#
#     class SpikeApp < UI::App
#       initial_route :sign_in
#
#       screen :sign_in, SignInController     # → SignInScreen by convention
#       screen :todos,   TodosController      # → TodosScreen by convention
#       screen :detail,  DetailController, screen_class: DetailScreen
#     end
#
# Per [[project_crystal_ios_class_init_gap]]: on iOS embedding the
# class-init pass may silently skip class-var initialiser side effects.
# A class-var-side-effect-based recovery hatch (e.g. an
# `@@_bootstrap_registrations` proc list) would be just as vulnerable —
# the gap that silently skipped the `@@screens[...] = ...` write would
# also silently skip the proc-append. So we use a different mechanism:
#
# Every `screen :foo, FooController` macro call generates a NAMED
# class-method `def self._bootstrap_screen_foo; @@screens[:foo] = ...; end`.
# Method definitions are class-text emitted by macro expansion — they
# exist at COMPILE time, not at module-load time, and are reachable
# regardless of whether `_main` runs. `bootstrap!` is itself macro-
# generated via `macro inherited` so each subclass gets its own
# generated body listing the explicit method calls.
#
# iOS apps invoke `MyApp.bootstrap!` from their bridge entry function
# AFTER `Thread.init` / `Fiber.init` / `Crystal::Once.init`. macOS /
# web also get a working `bootstrap!` (no-op if @@screens is already
# populated — registrations are idempotent re-assignments).

require "../ui"
require "./amber_integration"
require "./action_result"

module UI
  # Forward declaration so `UI::App::ScreenRegistration` can carry a
  # `UI::Controller.class` value before `UI::Controller` lands in
  # `native_controller.cr`. The full abstract class definition lives in
  # that file.
  abstract class Controller
  end

  abstract class App
    # Registry of route_id => ScreenRegistration. The default-value
    # `class_getter` form would create the hash at module-load time —
    # which iOS embedding can silently skip. So we declare it nilable
    # and lazy-allocate via the `screens` accessor, which on first
    # access creates the hash. `bootstrap!` also force-assigns a fresh
    # hash to recover if the lazy-allocator's class-var write itself
    # stranded under the iOS gap.
    @@screens : Hash(Symbol, UI::App::ScreenRegistration)? = nil

    def self.screens : Hash(Symbol, UI::App::ScreenRegistration)
      @@screens ||= {} of Symbol => UI::App::ScreenRegistration
    end

    # The route_id chosen as the navigation root. Override via the
    # `initial_route` macro. Default `:_unset` is a sentinel that the
    # dispatcher's `launch_*` helper detects and raises against.
    class_getter initial_route_id : Symbol = :_unset

    # A single registered screen. The dispatcher looks one up by
    # `route_id` to find which controller to construct + which screen
    # class to render.
    record ScreenRegistration,
      route_id : Symbol,
      controller_class : UI::Controller.class,
      screen_class : UI::Screen.class

    # Declare the initial route on launch.
    #
    #     class SpikeApp < UI::App
    #       initial_route :sign_in
    #     end
    macro initial_route(route_id)
      class_getter initial_route_id : Symbol = {{route_id}}
    end

    # Register a screen with its controller. Screen class can be omitted —
    # convention is `FooController` -> `FooScreen` (under the same
    # namespace).
    #
    #     screen :sign_in, SignInController
    #     screen :detail,  DetailController, screen_class: CustomScreen
    macro screen(route_id, controller, screen_class = nil)
      {% screen_lookup = screen_class || (controller.stringify.gsub(/Controller$/, "Screen").id) %}

      # Class-load side effect for the macOS / web happy path. The
      # `screens` accessor lazy-allocates if `@@screens` is nil. If the
      # iOS class-init gap skips this write entirely, `bootstrap!`
      # re-runs the registration via the generated method below.
      screens[{{route_id}}] = UI::App::ScreenRegistration.new(
        route_id: {{route_id}},
        controller_class: {{controller}},
        screen_class: {{screen_lookup}},
      )

      # Compile-time-emitted named class method. Crystal method
      # definitions exist at COMPILE time, not module-load time, so
      # they are reachable regardless of whether the iOS embedding ran
      # `_main`'s class-init pass. `bootstrap!` calls every such
      # method on the subclass.
      def self._bootstrap_screen_{{route_id.id}} : Nil
        screens[{{route_id}}] = UI::App::ScreenRegistration.new(
          route_id: {{route_id}},
          controller_class: {{controller}},
          screen_class: {{screen_lookup}},
        )
        nil
      end
    end

    # Optional: per-app design-token override block. The block receives
    # the default `Tokens` instance and must RETURN a (possibly
    # transformed) `Tokens`. Macro hygiene means we can't expose a local
    # variable named `tokens` for the block to reassign, so the contract
    # is "block in, transformed Tokens out".
    #
    #     design_tokens do |tokens|
    #       tokens.copy_with(touch_target_minimum_px: 51.0)
    #     end
    #
    #     design_tokens do |tokens|
    #       tokens.with_brand(AcmeBrand.new)
    #     end
    macro design_tokens(&block)
      class_getter app_design_tokens : UI::DesignTokens::Tokens = begin
        block = ->({{block.args.first || "tokens".id}} : UI::DesignTokens::Tokens) : UI::DesignTokens::Tokens {
          {{block.body}}
        }
        block.call(UI::DesignTokens::Tokens.default)
      end
    end

    # If the consumer did not declare `design_tokens do ... end`, this
    # default getter returns the framework default. Subclasses that
    # invoke the `design_tokens` macro shadow this with a class-getter
    # whose initializer applies the block body.
    class_getter app_design_tokens : UI::DesignTokens::Tokens = UI::DesignTokens::Tokens.default

    # Look up a screen registration by route_id. Raises
    # `UI::App::UnknownRouteError` with the list of known routes if the
    # id is not registered.
    def self.registration_for(route_id : Symbol) : ScreenRegistration
      registry = screens
      registry[route_id]? || raise UI::App::UnknownRouteError.new(
        "No screen registered for route_id #{route_id.inspect}. " \
        "Available routes: #{registry.keys.inspect}"
      )
    end

    # Default `bootstrap!` on the abstract `UI::App` itself — no-op
    # (no screens to register). Subclasses override via the
    # `macro inherited` hook below, which uses `macro finished` to
    # enumerate every `_bootstrap_screen_*` method that the `screen`
    # macro emitted and emit explicit calls to each.
    def self.bootstrap! : Nil
      nil
    end

    # Test helper: simulate the iOS class-init gap failure mode by
    # forcing `@@screens` back to nil (the state the gap would
    # produce if the class-var default initialiser never ran).
    # Not part of the public surface — exposed only so the spec can
    # prove `bootstrap!` recovers from a stranded-nil registry.
    def self.bootstrap_simulate_ios_gap! : Nil
      @@screens = nil
      nil
    end

    # When any class subclasses `UI::App`, install a generated
    # `bootstrap!` whose body explicitly calls every `_bootstrap_screen_*`
    # method on the subclass. Wrapped in `macro finished` so the
    # enumeration sees every `screen` macro call inside the subclass
    # body — `inherited` alone fires too early (at the start of the
    # subclass declaration).
    macro inherited
      macro finished
        def self.bootstrap! : Nil
          # Force-assign a fresh registry hash. If the iOS class-init
          # gap stranded `@@screens` as nil, this write recovers it.
          # If `@@screens` is already populated (macOS / web happy path
          # or a prior bootstrap! call), we still want to reset to a
          # clean slate before re-registering — registrations are
          # idempotent and the writes are deterministic.
          @@screens = {} of Symbol => UI::App::ScreenRegistration
          \{% for method in @type.class.methods %}
            \{% if method.name.starts_with?("_bootstrap_screen_") %}
              \{{method.name}}
            \{% end %}
          \{% end %}
          nil
        end
      end
    end

    class UnknownRouteError < Exception
    end
  end
end
