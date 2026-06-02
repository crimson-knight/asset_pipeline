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
    @@root : UI::NativeView? = nil # pin the rendered tree against GC across the Swift round-trip

    def self.initialize_runtime : Nil
      return if @@initialized
      GC.init
      # Runtime subsystems __crystal_main normally inits but the watch embedding skips.
      Thread.init
      Fiber.init
      Crystal::Once.init

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
      @@root = native # pin against GC across the Swift round-trip
      native.handle.ptr!
    end
  end

  fun voyager_watch_render : Void*
    VoyagerWatchBridge.render
  end
{% end %}
