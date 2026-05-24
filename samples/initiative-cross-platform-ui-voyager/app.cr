# Phase 6.10 + Phase 8D.1 — Voyager demo app.
#
# A navigable Todos CRUD demo, refactored in Phase 8D.1 to use the
# unified Phase 8B UI::App + UI::Controller + UI::ActionDispatcher
# architecture. The screens are now `UI::Screen` subclasses with
# `build(ctx : UI::ScreenContext) : UI::View`; their callbacks dispatch
# action refs through `Voyager.dispatch(:action_name, action_params)`,
# which routes to the controller layer (one controller per route).
#
# Routes (4):
#   :sign_in       -> SignInScreen     / SignInController
#   :todos         -> TodosScreen      / TodosController
#   :todo_editor   -> TodoEditorScreen / TodoEditorController
#   :settings      -> SettingsScreen   / SettingsController
#
# Phase 8D.1 keeps `Voyager.build_route(state, coord, route)` alive as
# a temporary COMPATIBILITY SHIM so iOS bridge.cr + web/static_site.cr
# continue to compile + run unchanged. Phase 8D.2 will migrate iOS to
# the dispatcher and may drop the shim; Phase 8D.3 evaluates the web
# dependency. The shim constructs a minimal ScreenContext::Native (no
# dispatcher attached) so user-intent callbacks become no-ops in the
# shim path — that matches today's web (static HTML + JS) and iOS
# (Swift-driven re-render via voyager_render) flows, which do NOT
# expect Crystal callbacks to do navigation work.

require "../../src/ui"
require "../../src/asset_pipeline/native_app"
require "../../src/asset_pipeline/native_controller"
require "../../src/asset_pipeline/action_dispatcher"
require "../../src/asset_pipeline/action_result"
require "../../src/asset_pipeline/native_context"

require "./screens/state"

require "./screens/sign_in"
require "./screens/todos"
require "./screens/todo_editor"
require "./screens/settings"

require "./controllers/sign_in_controller"
require "./controllers/todos_controller"
require "./controllers/todo_editor_controller"
require "./controllers/settings_controller"

module Voyager
  SLUGS = ["voyager-sign-in", "voyager-todos", "voyager-todo-editor", "voyager-settings"]

  # Phase 8D.1 — host-set dispatcher.
  #
  # macOS host (and 8D.2 iOS host) constructs a `UI::ActionDispatcher`
  # and assigns it here so screen callback closures can route action
  # refs through `Voyager.dispatch(:submit)` /
  # `Voyager.dispatch(:edit_row, {"todo_id" => "5"})` without each
  # screen capturing a dispatcher reference. The compat shim
  # (`Voyager.build_route`) leaves this nil — the static-site web path
  # and iOS render-on-demand path don't dispatch; user-intent callbacks
  # on those targets become no-ops (web uses JS for nav; iOS bridge is
  # migrated in Phase 8D.2).
  #
  # iOS class-init gap (see `project_crystal_ios_class_init_gap` memory):
  # deliberately a nilable default — no class-var initializer side
  # effects.
  @@dispatcher : UI::ActionDispatcher? = nil

  def self.dispatcher : UI::ActionDispatcher?
    @@dispatcher
  end

  def self.dispatcher=(d : UI::ActionDispatcher?) : UI::ActionDispatcher?
    @@dispatcher = d
  end

  # Convenience: dispatch a Symbol action_ref through the host's
  # ActionDispatcher. No-op when no dispatcher is set (static-site web +
  # current iOS bridge). Per the brief's action-ref convention, the
  # Symbol form runs the action on the CURRENTLY MOUNTED route's
  # registered controller; the optional action_params hash forwards to
  # ctx.action_params.
  def self.dispatch(name : Symbol, action_params : Hash(String, String) = {} of String => String) : Nil
    d = @@dispatcher
    return nil if d.nil?
    d.dispatch(name, action_params)
    nil
  end

  # Phase 8D.1 COMPATIBILITY SHIM.
  #
  # iOS bridge.cr + web/static_site.cr still call this. The shim
  # constructs a minimal ScreenContext::Native (no dispatcher
  # attached) so the screen's `build` method has the abstract
  # `ScreenContext` parameter shape it now expects, and renders the
  # screen via its registered class. Sets `Voyager.state` to the
  # passed-in state for the duration so screens reading
  # `Voyager.state` get the caller's instance.
  #
  # NOTE on brief signature: the brief shows
  # `UI::ScreenContext::Native.new(params:, action_params:, form_state:,
  # session:, flash:)` but the actual `ScreenContext::Native#initialize`
  # signature is `(form_state, session, flash, design_tokens,
  # navigation, action_params)` — no `params:` kwarg (params is
  # derived from `form_state.to_h`), and no `route_id` on FormState.
  # Documented in the Phase 8D.1 implementer report as a brief
  # inaccuracy (NOT a Phase 8B API gap).
  def self.build_route(state : State, coord : UI::NavigationCoordinator, route : UI::NavigationCoordinator::Route) : UI::View
    # Make the per-call state visible to screens that read
    # `Voyager.state`.
    Voyager.state = state

    reg = VoyagerApp.registration_for(route.id)
    screen_class = reg.screen_class
    if screen_class.nil?
      placeholder = UI::Label.new("Unknown screen for route: #{route.id}")
      placeholder.accessibility_label = "Unknown route"
      return placeholder.as(UI::View)
    end

    # Seed a fresh FormState with route.params (string keys) so the
    # editor screen's `ctx.params["todo_id"]` works when the shim is
    # exercising it (e.g. spec/ui/voyager_state_propagation_spec.cr's
    # editor flow).
    fs = UI::FormState.new(mount_token: 0_i64)
    route.params.each { |k, v| fs.register(k.to_s, v) }

    ctx = UI::ScreenContext::Native.new(
      form_state: fs,
      session: UI::Session::InProcess.new,
      flash: UI::Flash::InProcess.new,
      design_tokens: UI::DesignTokens::Tokens.default,
      navigation: coord,
      action_params: {} of String => String,
    )
    screen_class.new.build(ctx)
  end

  # Map a static slug ("voyager-todos") to a Route. Used by the web
  # static-site generator (which renders one fragment per known slug
  # at build time) and by the iOS/macOS hosts when they need to
  # pre-build a route by name.
  def self.route_for_slug(slug : String) : UI::NavigationCoordinator::Route
    case slug
    when "voyager-sign-in"     then UI::NavigationCoordinator::Route.new(:sign_in)
    when "voyager-todos"       then UI::NavigationCoordinator::Route.new(:todos)
    when "voyager-todo-editor" then UI::NavigationCoordinator::Route.new(:todo_editor)
    when "voyager-settings"    then UI::NavigationCoordinator::Route.new(:settings)
    else                            UI::NavigationCoordinator::Route.new(:sign_in)
    end
  end

  # Slug for a Route.id (inverse of route_for_slug). Used by the
  # web renderer's UIRouteHost push glue.
  def self.slug_for_route_id(route_id : Symbol) : String
    case route_id
    when :sign_in     then "voyager-sign-in"
    when :todos       then "voyager-todos"
    when :todo_editor then "voyager-todo-editor"
    when :settings    then "voyager-settings"
    else                   "voyager-sign-in"
    end
  end
end

# Phase 8D.1 — UI::App declaration. Routes are registered via the
# `screen` macro; bootstrap! re-runs the registrations defensively (iOS
# class-init gap recovery hatch — see src/asset_pipeline/native_app.cr).
class VoyagerApp < UI::App
  initial_route :sign_in
  screen :sign_in,     Voyager::SignInController
  screen :todos,       Voyager::TodosController
  screen :todo_editor, Voyager::TodoEditorController
  screen :settings,    Voyager::SettingsController
end
