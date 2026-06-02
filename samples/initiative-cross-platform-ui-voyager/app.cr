# Voyager demo app — unified UI::App / UI::Controller / UI::ActionDispatcher.
#
# A navigable Todos CRUD demo. Screens are `UI::Screen` subclasses with
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
# Native targets (macOS + iOS) drive screens through the dispatcher;
# the iOS bridge migrated in Phase 8D.2 and now dispatches actions
# through `UI::ActionDispatcher` (see `ios/bridge.cr`).
#
# `Voyager.build_route(state, coord, route)` survives as the permanent
# entry point for the static-site web target (`web/static_site.cr`) —
# the only caller post-8D.2. See
# `docs/initiative-cross-platform-ui/architecture/web-target-position.md`
# for the architectural rationale (Voyager web is deliberately
# static-site, not a full-server dispatcher path; the Amber spike in
# `samples/phase-08-amber-spike/` proves the dispatcher web target on
# a different sample). The shim constructs a minimal
# ScreenContext::Native (no dispatcher attached) so user-intent
# callbacks become no-ops on the static-site path — static HTML + JS
# handles navigation client-side.

require "../../src/ui"
require "../../src/asset_pipeline/native_app"
require "../../src/asset_pipeline/native_controller"
require "../../src/asset_pipeline/action_dispatcher"
require "../../src/asset_pipeline/action_result"
require "../../src/asset_pipeline/native_context"

require "./screens/state"

require "./screens/sign_in_screen"
require "./screens/todos_screen"
require "./screens/todo_editor_screen"
require "./screens/settings_screen"
require "./screens/component_gallery_state"
require "./screens/component_gallery_screen"
require "./screens/reconcile_probe_screen"
require "./screens/combo_probe_screen"
require "./screens/phase10_hub_screen"
require "./screens/phase_10/phase_10_exerciser_state"
require "./screens/phase_10/intent_resolver_screen"
require "./screens/phase_10/class_c_dispatch_screen"
require "./screens/phase_10/ax_metadata_screen"
require "./screens/phase_10/environment_reactivity_screen"
require "./screens/phase_10/new_widgets_screen"
require "./screens/welcome_screen"
require "./screens/agent_chat_screen"

require "./controllers/welcome_controller"
require "./controllers/agent_chat_controller"
require "./controllers/sign_in_controller"
require "./controllers/todos_controller"
require "./controllers/todo_editor_controller"
require "./controllers/settings_controller"
require "./controllers/component_gallery_controller"
require "./controllers/reconcile_probe_controller"
require "./controllers/combo_probe_controller"
require "./controllers/phase10_hub_controller"
require "./controllers/phase10_intent_resolver_controller"
require "./controllers/phase10_class_c_dispatch_controller"
require "./controllers/phase10_ax_metadata_controller"
require "./controllers/phase10_environment_reactivity_controller"
require "./controllers/phase10_new_widgets_controller"

# Phase 8D.3b — sample-local capture-scenario registry. No-op unless
# `VOYAGER_CAPTURE_SCENARIO` is set; the iOS bridge and macOS host both
# read that env var after constructing the dispatcher and call
# `Voyager::CaptureScenarios.apply` to walk into the target visual state.
require "./capture_scenarios"

module Voyager
  SLUGS = [
    "voyager-sign-in",
    "voyager-todos",
    "voyager-todo-editor",
    "voyager-settings",
    "voyager-component-gallery",
    "voyager-reconcile-probe",
    "voyager-combo-probe",
    "voyager-phase-10-hub",
    "voyager-phase-10-intent-resolver",
    "voyager-phase-10-class-c-dispatch",
    "voyager-phase-10-ax-metadata",
    "voyager-phase-10-environment",
    "voyager-phase-10-new-widgets",
    "voyager-welcome",
    "voyager-agent-chat",
  ]

  # Host-set dispatcher.
  #
  # macOS and iOS hosts each construct a `UI::ActionDispatcher` and
  # assign it here so screen callback closures can route action refs
  # through `Voyager.dispatch(:submit)` /
  # `Voyager.dispatch(:edit_row, {"todo_id" => "5"})` without each
  # screen capturing a dispatcher reference. The static-site web entry
  # point (`Voyager.build_route`) leaves this nil — the static HTML +
  # JS path handles navigation client-side, so user-intent callbacks
  # become no-ops on that target.
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
  # ActionDispatcher. No-op when no dispatcher is set (the static-site
  # web path leaves the dispatcher nil; native targets assign one
  # during host bootstrap). Per the brief's action-ref convention, the
  # Symbol form runs the action on the CURRENTLY MOUNTED route's
  # registered controller; the optional action_params hash forwards to
  # ctx.action_params.
  def self.dispatch(name : Symbol, action_params : Hash(String, String) = {} of String => String) : Nil
    d = @@dispatcher
    return nil if d.nil?
    d.dispatch(name, action_params)
    nil
  end

  # Static-site web entry point.
  #
  # Permanent entry point for the static-site web target
  # (`web/static_site.cr`) — the only caller post-8D.2. iOS migrated
  # to the dispatcher path in Phase 8D.2 and no longer calls this.
  # See
  # `docs/initiative-cross-platform-ui/architecture/web-target-position.md`
  # for the architectural rationale.
  #
  # Constructs a minimal ScreenContext::Native (no dispatcher
  # attached) so the screen's `build` method has the abstract
  # `ScreenContext` parameter shape it expects, and renders the
  # screen via its registered class. Sets `Voyager.state` to the
  # passed-in state for the duration so screens reading
  # `Voyager.state` get the caller's instance. User-intent
  # callbacks become no-ops on this path — static HTML + JS handles
  # navigation client-side.
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
    when "voyager-welcome"    then UI::NavigationCoordinator::Route.new(:welcome)
    when "voyager-agent-chat" then UI::NavigationCoordinator::Route.new(:agent_chat)
    when "voyager-sign-in"    then UI::NavigationCoordinator::Route.new(:sign_in)
    when "voyager-todos"   then UI::NavigationCoordinator::Route.new(:todos)
    when "voyager-todo-editor"
      # Phase 10D-final — capture-mode todo_id seeding. When the screenshot
      # capture flow launches the editor as the root slug, seed the
      # route's params with the env-var-supplied todo_id so the editor
      # mounts as "edit existing" rather than "new draft". Unset/blank
      # env → empty params (new-todo path).
      params = {} of Symbol => String
      if id = ENV["VOYAGER_EDITOR_TODO_ID"]?
        params[:todo_id] = id unless id.empty?
      end
      UI::NavigationCoordinator::Route.new(:todo_editor, params: params)
    when "voyager-settings"                  then UI::NavigationCoordinator::Route.new(:settings)
    when "voyager-component-gallery"         then UI::NavigationCoordinator::Route.new(:component_gallery)
    when "voyager-reconcile-probe"           then UI::NavigationCoordinator::Route.new(:reconcile_probe)
    when "voyager-combo-probe"               then UI::NavigationCoordinator::Route.new(:combo_probe)
    when "voyager-phase-10-hub"              then UI::NavigationCoordinator::Route.new(:phase_10_hub)
    when "voyager-phase-10-intent-resolver"  then UI::NavigationCoordinator::Route.new(:phase_10_intent_resolver)
    when "voyager-phase-10-class-c-dispatch" then UI::NavigationCoordinator::Route.new(:phase_10_class_c_dispatch)
    when "voyager-phase-10-ax-metadata"      then UI::NavigationCoordinator::Route.new(:phase_10_ax_metadata)
    when "voyager-phase-10-environment"      then UI::NavigationCoordinator::Route.new(:phase_10_environment)
    when "voyager-phase-10-new-widgets"      then UI::NavigationCoordinator::Route.new(:phase_10_new_widgets)
    else                                          UI::NavigationCoordinator::Route.new(:sign_in)
    end
  end

  # Slug for a Route.id (inverse of route_for_slug). Used by the
  # web renderer's UIRouteHost push glue.
  def self.slug_for_route_id(route_id : Symbol) : String
    case route_id
    when :welcome                   then "voyager-welcome"
    when :agent_chat                then "voyager-agent-chat"
    when :sign_in                   then "voyager-sign-in"
    when :todos                     then "voyager-todos"
    when :todo_editor               then "voyager-todo-editor"
    when :settings                  then "voyager-settings"
    when :component_gallery         then "voyager-component-gallery"
    when :reconcile_probe           then "voyager-reconcile-probe"
    when :combo_probe               then "voyager-combo-probe"
    when :phase_10_hub              then "voyager-phase-10-hub"
    when :phase_10_intent_resolver  then "voyager-phase-10-intent-resolver"
    when :phase_10_class_c_dispatch then "voyager-phase-10-class-c-dispatch"
    when :phase_10_ax_metadata      then "voyager-phase-10-ax-metadata"
    when :phase_10_environment      then "voyager-phase-10-environment"
    when :phase_10_new_widgets      then "voyager-phase-10-new-widgets"
    else                                 "voyager-sign-in"
    end
  end
end

# UI::App declaration. Routes are registered via the `screen` macro;
# bootstrap! re-runs the registrations defensively (iOS class-init
# gap recovery hatch — see src/asset_pipeline/native_app.cr).
class VoyagerApp < UI::App
  initial_route :sign_in
  screen :welcome, Voyager::WelcomeController, screen_class: Voyager::WelcomeScreen
  screen :agent_chat, Voyager::AgentChatController, screen_class: Voyager::AgentChatScreen
  screen :sign_in, Voyager::SignInController
  screen :todos, Voyager::TodosController
  screen :todo_editor, Voyager::TodoEditorController
  screen :settings, Voyager::SettingsController
  screen :component_gallery, Voyager::ComponentGalleryController, screen_class: Voyager::ComponentGalleryScreen
  screen :reconcile_probe, Voyager::ReconcileProbeController, screen_class: Voyager::ReconcileProbeScreen
  screen :combo_probe, Voyager::ComboProbeController, screen_class: Voyager::ComboProbeScreen
  # Phase 10D — exerciser routes. Reachable from the Settings screen
  # via a "Phase 10 Exerciser" entry, or directly via /phase-10 on the
  # static-site web build.
  screen :phase_10_hub, Voyager::Phase10HubController, screen_class: Voyager::Phase10HubScreen
  screen :phase_10_intent_resolver, Voyager::Phase10IntentResolverController, screen_class: Voyager::IntentResolverScreen
  screen :phase_10_class_c_dispatch, Voyager::Phase10ClassCDispatchController, screen_class: Voyager::ClassCDispatchScreen
  screen :phase_10_ax_metadata, Voyager::Phase10AxMetadataController, screen_class: Voyager::AxMetadataScreen
  screen :phase_10_environment, Voyager::Phase10EnvironmentReactivityController, screen_class: Voyager::EnvironmentReactivityScreen
  screen :phase_10_new_widgets, Voyager::Phase10NewWidgetsController, screen_class: Voyager::NewWidgetsScreen
end
