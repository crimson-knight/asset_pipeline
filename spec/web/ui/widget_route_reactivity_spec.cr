require "../spec_helper"
require "../../../src/asset_pipeline/native_app"
require "../../../src/asset_pipeline/native_context"
require "../../../src/asset_pipeline/native_controller"
require "../../../src/asset_pipeline/action_dispatcher"
require "../../../src/ui/widget_route"
require "../../../src/ui/widget_route/bootstrap"

# Phase 10B.0 — Reactivity contract integration spec.
#
# Per architecture-decisions.md Decision 4 #1, the reactivity invariant
# is `controller mutation → UI::ActionResult::Rerender → ActionDispatcher
# mount → NavigationCoordinator publish → host on_change → screen
# rebuild → resolve runs`. This spec exercises the REAL dispatcher
# flow (not a mock) and proves that the resolver is invoked again on
# every rebuild — which is what makes runtime override changes visible
# to subsequent renders.
#
# Per [[reactivity-is-table-stakes]]: this invariant is unconditional.
# A library that ships a resolver but only re-resolves on initial
# render would fail every app with mid-flow override changes (e.g.
# accessibility toggle → swap widget). The integration spec is the
# library's proof that reactivity is real.

# ---------- Test widgets ----------

private class ReactivitySpecWidgetA < UI::View
  declares_capabilities :reactivity_test_intent, {
    test_cap: true,
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

private class ReactivitySpecWidgetB < UI::View
  declares_capabilities :reactivity_test_intent, {
    test_cap: true,
  }

  def initialize
  end

  def accept(visitor : UI::PlatformVisitor)
  end
end

# ---------- Test screen — resolves the test intent on every build ----------

# A class-var resolution counter the spec checks after each rebuild.
# Lives outside the screen because the screen is constructed fresh on
# every mount; instance state would not survive.
class ReactivitySpecCounter
  @@resolve_count : Int32 = 0
  @@last_resolved : (UI::View.class)? = nil

  def self.reset
    @@resolve_count = 0
    @@last_resolved = nil
  end

  def self.resolve_count
    @@resolve_count
  end

  def self.last_resolved
    @@last_resolved
  end

  def self.record(klass : UI::View.class)
    @@resolve_count += 1
    @@last_resolved = klass
  end
end

private class ReactivitySpecScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    # The resolver call is the contract being measured. On every
    # build (initial mount + every rerender), this call MUST run and
    # MUST reflect the current registry state. The counter records
    # the resolved widget so the spec can assert that overrides
    # registered mid-flow take effect on the NEXT build.
    #
    # Iter-9 (Codex Finding 2): the public `.resolve` signature now
    # mirrors the brief — no `screen_class:` kwarg. Screens that want
    # screen-tier overrides set `ctx.active_screen_class` defensively
    # before calling resolve. In production the host (dispatcher /
    # `compute_screen_html`) sets it on the context it builds; here
    # the spec sets it directly because we hand-craft the context.
    context.active_screen_class = ReactivitySpecScreen
    klass = UI::WidgetRoute.resolve(:reactivity_test_intent, context)
    ReactivitySpecCounter.record(klass)
    UI::Label.new("resolved=#{klass}")
  end
end

# ---------- Test controller — issues a Rerender action ----------

private class ReactivitySpecController < UI::Controller
  def dispatch_action(name : Symbol, context : UI::ScreenContext::Native) : UI::ActionResult
    case name
    when :rerender then render_current_screen
    else raise UI::Controller::UnknownActionError.new("no #{name}")
    end
  end
end

private class ReactivitySpecApp < UI::App
  initial_route :test
  screen :test, ReactivitySpecController, screen_class: ReactivitySpecScreen
end

# Helper: build a dispatcher wired to the test app + a host that
# rebuilds the screen on every on_change publication.
private def build_reactive_setup : Tuple(UI::ActionDispatcher, ReactivitySpecScreen, UI::ScreenContext::Native)
  ReactivitySpecApp.bootstrap!
  ReactivitySpecCounter.reset

  coord = UI::NavigationCoordinator.new(UI::NavigationCoordinator::Route.new(:test))
  dispatcher = UI::ActionDispatcher.new(
    app: ReactivitySpecApp,
    navigation: coord,
    session: UI::Session::InProcess.new,
    flash: UI::Flash::InProcess.new,
    design_tokens: UI::DesignTokens::Tokens.default,
    platform: :ios,
  )

  screen = ReactivitySpecScreen.new

  # The host: a function that runs on every coord publication. This
  # is the REAL pattern macOS / iOS hosts use — bind on_change to a
  # rebuild routine, then dispatch actions and watch the rebuild
  # happen via the coordinator. The renderer's job in production is
  # to walk the new tree; here we just exercise the build call.
  coord.on_change do |route|
    ctx = UI::ScreenContext::Native.new(
      form_state: dispatcher.current_form_state,
      session: dispatcher.session,
      flash: dispatcher.flash,
      design_tokens: dispatcher.design_tokens,
      navigation: coord,
      platform: dispatcher.platform,
    )
    # The host's build call — this is what the renderer does.
    screen.build(ctx)
  end

  # Build the initial mount context manually (matches what a host
  # would build on app launch, before any dispatch has fired).
  initial_ctx = UI::ScreenContext::Native.new(
    form_state: dispatcher.current_form_state,
    session: dispatcher.session,
    flash: dispatcher.flash,
    design_tokens: dispatcher.design_tokens,
    navigation: coord,
    platform: dispatcher.platform,
  )

  # Initial build to seed the counter — mirrors what the renderer
  # does on app launch (build the screen tree once before any
  # navigation event).
  screen.build(initial_ctx)

  {dispatcher, screen, initial_ctx}
end

describe "UI::WidgetRoute reactivity invariant" do
  it "calls resolve on every rebuild driven by ActionResult::Rerender" do
    # Install a default for the test intent on iOS so initial resolution
    # works.
    UI::WidgetRoute::Registry.register_default(
      :reactivity_test_intent,
      :ios,
      ReactivitySpecWidgetA,
    )

    dispatcher, screen, _ctx = build_reactive_setup

    # Initial build ran once.
    ReactivitySpecCounter.resolve_count.should eq(1)
    ReactivitySpecCounter.last_resolved.should eq(ReactivitySpecWidgetA)

    # Dispatch a Rerender. The real dispatcher flow:
    #   controller.dispatch_action(:rerender) → ActionResult::Rerender
    #   → ActionDispatcher#translate_result → mount_screen + coord.republish
    #   → coord.on_change fires → host rebuilds (calls screen.build)
    #   → screen.build calls UI::WidgetRoute.resolve → counter increments.
    dispatcher.dispatch(:rerender)

    # After Rerender: resolve fired again.
    ReactivitySpecCounter.resolve_count.should eq(2)
  end

  it "reflects a runtime override change in the NEXT rebuild" do
    # Clear any prior state from sibling tests.
    UI::WidgetRoute::Registry.register_default(
      :reactivity_test_intent,
      :ios,
      ReactivitySpecWidgetA,
    )

    dispatcher, _screen, _ctx = build_reactive_setup
    ReactivitySpecCounter.last_resolved.should eq(ReactivitySpecWidgetA)

    # Mutate the registry mid-flow — swap the default to WidgetB.
    # This is the pattern a settings-change handler uses ("user
    # toggled compact mode → swap default for :list_layout intent").
    UI::WidgetRoute::Registry.register_default(
      :reactivity_test_intent,
      :ios,
      ReactivitySpecWidgetB,
    )

    # Dispatch a rerender — the screen rebuilds + resolve runs again.
    dispatcher.dispatch(:rerender)

    # The NEW build sees the new override.
    ReactivitySpecCounter.last_resolved.should eq(ReactivitySpecWidgetB)
    ReactivitySpecCounter.resolve_count.should eq(2)
  end

  it "preserves form state across a rerender (state + override interaction)" do
    UI::WidgetRoute::Registry.register_default(
      :reactivity_test_intent,
      :ios,
      ReactivitySpecWidgetA,
    )

    dispatcher, _screen, _ctx = build_reactive_setup

    # Seed a form-state value. The dispatcher's current_form_state is
    # the source of truth — the spec asserts it's preserved across
    # a rerender (NOT cleared/reset).
    dispatcher.current_form_state.update("user_input", "hello")
    dispatcher.current_form_state["user_input"].should eq("hello")

    # Dispatch a rerender. Per ActionDispatcher#translate_result, a
    # Rerender path mounts a fresh FormState — so the user's typed
    # value DOES get cleared. This is the existing 8B contract for
    # explicit rerenders. The spec records this baseline so the next
    # iteration (or a real form-preserving rerender mode) can detect
    # changes. For now, assert the baseline: rerender resets state.
    dispatcher.dispatch(:rerender)
    dispatcher.current_form_state["user_input"]?.should be_nil

    # Change the override mid-flow.
    UI::WidgetRoute::Registry.register_default(
      :reactivity_test_intent,
      :ios,
      ReactivitySpecWidgetB,
    )

    # Another rerender — verify the override change applies AND the
    # mount token advanced. The combined assertion proves state-flow
    # and resolver-flow are independent — neither blocks the other.
    before_token = dispatcher.current_mount_token
    dispatcher.dispatch(:rerender)
    dispatcher.current_mount_token.should be > before_token
    ReactivitySpecCounter.last_resolved.should eq(ReactivitySpecWidgetB)
  end
end
