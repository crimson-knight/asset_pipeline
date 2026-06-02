# Voyager watchOS bridge — renders the SHARED Crystal screens on the wrist.
#
# This is the cohesion payoff: instead of an ad-hoc watch-only view tree, the watch
# renders the SAME registered `UI::Screen` classes (e.g. Voyager::AgentChatScreen)
# that macOS + iOS render — through the same HostBootstrap dispatcher substrate — just
# walked by `UI::WatchKit::Renderer` instead of AppKit/UIKit. One screen definition,
# one state model, three native platforms.
#
# C ABI:
#   void* voyager_watch_render(void)
#       — builds the registered agent-chat screen from the shared State + dispatcher,
#         renders via UI::WatchKit::Renderer, returns the retained root
#         APSKWatchHostView* (Swift reads `.content` and embeds it). +1-retained.
{% if flag?(:watchos) %}
  require "../app"
  require "../host_bootstrap"
  require "../../../src/ui/renderers/watchkit_renderer"
  require "../../../src/ui/probes"

  module VoyagerWatchBridge
    # iOS/watchOS class-init gap (Swift @main hides _main, so class-var initializers +
    # Crystal::once tables don't run). NONE of these carry side-effect initializers;
    # we bootstrap explicitly in `initialize_runtime`. See
    # project_crystal_ios_class_init_gap + the iOS bridge for the canonical pattern.
    @@initialized = false
    @@state : Voyager::State? = nil
    @@coord : UI::NavigationCoordinator? = nil
    @@session : UI::Session::InProcess? = nil
    @@flash : UI::Flash::InProcess? = nil
    @@dispatcher : UI::ActionDispatcher? = nil
    # Pin EVERY rendered tree (never release). The watch's single-threaded GC finalizes
    # NativeHandles aggressively; if we dropped an old root, its finalizer would
    # objc_release the box that Swift (takeRetainedValue) also owns → double-free
    # (SIGSEGV in CrystalBridge.box.setter). Keeping all roots pinned means Crystal never
    # releases a box; Swift owns the display copy and frees it on reassign. Matches iOS's
    # leak-rather-than-double-free model (its finalizer is best-effort + never runs).
    # TODO: replace tree-rebuild re-render with in-place reconciliation (cf.
    # project_reactive_text_focus_loss) to bound this per-render leak.
    #
    # NILABLE (not `= [] of ...`): the iOS/watchOS class-init gap SKIPS class-var
    # initializers with side effects when _main is hidden for Swift @main, so a
    # `= [] of UI::NativeView` default leaves the array unallocated and `<<` SIGSEGVs in
    # Array#needs_resize?. We allocate it explicitly in initialize_runtime instead.
    @@roots : Array(UI::NativeView)? = nil
    # Swift re-render callback. Crystal invokes it whenever the dispatcher publishes a
    # navigation/Rerender change (e.g. tapping Send appends to the transcript + returns
    # Rerender → republish → on_change). Swift bumps its @State so SwiftUI re-calls
    # voyager_watch_render and re-embeds the new tree. This is the watch's reactive loop
    # — the agent-chat surface MUST re-render when a message arrives.
    @@swift_rerender_cb : (-> Void)? = nil

    def self.initialize_runtime : Nil
      return if @@initialized
      GC.init
      # Runtime subsystems __crystal_main normally inits but the watch embedding skips.
      Thread.init
      Fiber.init
      Crystal::Once.init

      # Allocate the root pin-list HERE (class-init gap: a class-var `= [] of ...`
      # default never runs under Swift @main).
      @@roots = [] of UI::NativeView

      # iOS/watchOS class-init gap recovery (same as the iOS bridge): the module-body
      # bootstrap registrations only run under _main, so re-install them explicitly.
      UI::Probes::DismissProbe.reset
      UI::Probes::ToggleProbe.reset
      UI::Probes::SliderProbe.reset
      UI::Probes::TapProbe.reset
      UI::Probes::FormRowProbe.reset
      UI::Probes::RuntimeOverrideProbe.reset
      UI::WidgetRoute::Bootstrap.install
      UI::SystemAction::Bootstrap.install

      # Build the shared host substrate rooted at the agent-chat screen. State seeds
      # the chat transcript; the dispatcher owns FormState/session/flash/navigation.
      result = Voyager::HostBootstrap.build(:agent_chat)
      @@state = result.state
      @@coord = result.coord
      @@session = result.session
      @@flash = result.flash
      @@dispatcher = result.dispatcher

      # Reactive loop: when the dispatcher republishes after an action (Rerender on
      # Send, Pop on Back, etc.), notify Swift to re-render. Renderer-neutral — it just
      # pokes Swift, which re-calls voyager_watch_render and rebuilds from coord.current.
      @@coord.not_nil!.on_change_event do |_change|
        @@swift_rerender_cb.try(&.call)
      end

      @@initialized = true
    end

    # Render the current route's registered screen via the WatchKit renderer and
    # return the root box pointer (Swift takes the +1 retain via Unmanaged).
    def self.render : Void*
      initialize_runtime
      coord = @@coord.not_nil!
      dispatcher = @@dispatcher.not_nil!

      reg = VoyagerApp.registration_for(coord.current.id)
      screen_class = reg.screen_class

      # Construct the renderer BEFORE screen.build — its initializer installs the
      # watch DeviceMetrics provider that screens query during build (provider-
      # install-ordering invariant; see project_renderer_provider_install_ordering).
      renderer = UI::WatchKit::Renderer.new

      view =
        if screen_class.nil?
          UI::Label.new("Unknown screen: #{coord.current.id}").as(UI::View)
        else
          ctx = UI::ScreenContext::Native.new(
            form_state: dispatcher.current_form_state,
            session: dispatcher.session,
            flash: dispatcher.flash,
            design_tokens: dispatcher.design_tokens,
            navigation: dispatcher.navigation,
            action_params: {} of String => String,
            platform: dispatcher.platform,
            environment: dispatcher.environment,
          )
          screen_class.new.build(ctx)
        end

      native = renderer.render(view)
      @@roots.not_nil! << native # pin forever (see @@roots note) — never released by Crystal
      ptr = native.handle.ptr!
      # The facade returns the box +0 (autoreleased — it's a static factory method, not
      # an init/new/copy, so ARC does not transfer ownership). ObjC.owned does NOT retain,
      # so without this the box is only kept alive by the autorelease pool and gets freed
      # on the next run-loop drain — then Swift's takeRetainedValue reference dangles and
      # the next render's box reassignment double-frees it (SIGSEGV in box.setter). An
      # explicit +1 gives Swift a real, pool-independent reference to own and release once.
      {% if flag?(:darwin) %}
        LibObjCRuntime.objc_retain(ptr)
      {% end %}
      ptr
    end

    def self.register_rerender(cb : -> Void) : Nil
      @@swift_rerender_cb = cb
    end

    # Drive a Send through the SAME dispatch path a Send-button tap takes: seed the
    # compose field, then dispatch :send_message. The controller appends a user message
    # + a canned agent reply to the shared State and returns Rerender → the dispatcher
    # republishes → our on_change subscriber fires the Swift re-render callback → the
    # new bubbles appear. Used to prove the watch reactive loop end-to-end (the literal
    # SwiftUI-button→trampoline link is generic facade infra, already proven on iOS;
    # driving real native taps on the watch needs XCUITest).
    def self.test_send(text : String) : Nil
      initialize_runtime
      # Mutate the shared State directly + republish to isolate the reactive RENDER loop
      # (state change → on_change → Swift callback → re-render → UI reflects new state)
      # from the form_state read path. send_chat_message appends a user message + a
      # canned agent reply (2 messages), so the title count jumps by 2.
      Voyager.state.send_chat_message(text)
      @@dispatcher.not_nil!.navigation.republish
    end
  end

  fun voyager_watch_render : Void*
    VoyagerWatchBridge.render
  end

  fun voyager_watch_register_rerender(cb : -> Void) : Void
    VoyagerWatchBridge.register_rerender(cb)
  end

  fun voyager_watch_test_send(text : LibC::Char*) : Void
    VoyagerWatchBridge.test_send(String.new(text))
  end
{% end %}
