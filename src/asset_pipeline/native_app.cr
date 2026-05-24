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
# class-init pass may silently skip the side-effecting macro bodies
# that `screen` expands to. To mitigate, every `screen` macro call
# ALSO appends an idempotent re-registration proc to
# `@@_bootstrap_registrations`. iOS apps call `MyApp.bootstrap!` from
# their bridge entry function (after `Thread.init / Fiber.init /
# Crystal::Once.init`) which replays every registration. The proc
# list is itself default-initialised — same gap risk in theory, but
# the procs are class-load constants, and `bootstrap!` is invoked
# explicitly so any nil-strand surfaces as a clear NilAssertionError
# rather than a silent empty registry. macOS and web do not need to
# call `bootstrap!`; the macro side effects fire normally there.

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
    # Registry of route_id => ScreenRegistration, populated by `screen`
    # macros at class-load time.
    class_getter screens : Hash(Symbol, UI::App::ScreenRegistration) = {} of Symbol => UI::App::ScreenRegistration

    # iOS escape hatch: an idempotent list of registration procs. Every
    # `screen` macro appends one. Apps call `MyApp.bootstrap!` from
    # their iOS bridge entry point to force re-registration in case
    # the iOS class-init gap silently skipped the macro body.
    class_getter _bootstrap_registrations : Array(Proc(Nil)) = [] of Proc(Nil)

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
      @@screens[{{route_id}}] = UI::App::ScreenRegistration.new(
        route_id: {{route_id}},
        controller_class: {{controller}},
        screen_class: {{screen_lookup}},
      )
      @@_bootstrap_registrations << ->{
        @@screens[{{route_id}}] = UI::App::ScreenRegistration.new(
          route_id: {{route_id}},
          controller_class: {{controller}},
          screen_class: {{screen_lookup}},
        )
        nil
      }
    end

    # Optional: per-app design-token override block. The block body
    # mutates `tokens` (built from `UI::DesignTokens::Tokens.default`)
    # and the result is exposed as `app_design_tokens`.
    #
    #     design_tokens do
    #       tokens = tokens.with_brand(AcmeBrand.new)
    #     end
    macro design_tokens(&block)
      class_getter app_design_tokens : UI::DesignTokens::Tokens = begin
        tokens = UI::DesignTokens::Tokens.default
        {{block.body}}
        tokens
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
      @@screens[route_id]? || raise UI::App::UnknownRouteError.new(
        "No screen registered for route_id #{route_id.inspect}. " \
        "Available routes: #{@@screens.keys.inspect}"
      )
    end

    # iOS escape hatch — idempotent. Replays every recorded `screen`
    # macro registration. Calling on macOS/web is a harmless no-op
    # (re-assigning the same registry entries). iOS apps must call
    # this from their bridge entry function AFTER `Thread.init`,
    # `Fiber.init`, and `Crystal::Once.init`.
    def self.bootstrap! : Nil
      @@_bootstrap_registrations.each(&.call)
      nil
    end

    class UnknownRouteError < Exception
    end
  end
end
