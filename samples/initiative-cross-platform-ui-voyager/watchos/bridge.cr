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

      # Build the shared host substrate. Root at the agent-chat screen by default (the
      # watch's purpose surface), but honor VOYAGER_ROOT_SLUG like the iOS/macOS hosts so
      # any registered screen can be rendered/captured on the watch (proves the watch
      # renders the full screen catalog, not just one screen).
      root_id = Voyager.route_for_slug(ENV["VOYAGER_ROOT_SLUG"]? || "voyager-agent-chat").id
      result = Voyager::HostBootstrap.build(root_id)
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

    # Drive a real NAVIGATION the way a Settings "Daily check-in" button tap does:
    # dispatch :open_check_in → SettingsController returns Navigate(:check_in) → the
    # dispatcher mounts the new screen + coord.push → on_change → the Swift callback
    # re-renders coord.current (now :check_in). Proves the watch is a navigable
    # multi-screen app via the Navigate/push/mount_screen path — distinct from the
    # Rerender/republish path test_send exercises. (Bootstrap the watch at :settings.)
    def self.test_nav : Nil
      initialize_runtime
      Voyager.dispatch(:open_check_in)
    end

    # Drive a real Save on the Daily Check-in the way the Save button does —
    # dispatch :save_checkin → CheckInController schedules a REAL recurring local
    # notification via UI::Notifications (now wired for watchOS through
    # notifications_bridge.m) → Rerender. Returns the system's actual pending
    # count so the watch's lack of XCUITest is covered by an honest, machine-
    # checkable functional outcome (the request truly landed in
    # UNUserNotificationCenter on the wrist), not a screenshot guess. Root the
    # watch at :voyager-check-in for this to target the check-in controller.
    def self.test_notif : Int32
      initialize_runtime
      # Drive the REAL Save the way the Save button does — dispatch :save_checkin
      # → CheckInController requests provisional auth (silent) + schedules a real
      # recurring local notification via UI::Notifications. Return the system's
      # actual pending count (UNUserNotificationCenter) — the honest functional
      # outcome the watch can't get from XCUITest. Root the watch at
      # :voyager-check-in so this targets the check-in controller.
      Voyager.dispatch(:save_checkin)
      UI::Notifications.pending_count
    end

    # Speak a phrase via UI::Speech (AVSpeechSynthesizer) — the same call the
    # AgentChatController makes when the agent replies. Speech starts
    # asynchronously, so the caller checks `speaking` after a beat.
    def self.test_speak : Nil
      initialize_runtime
      UI::Speech.speak("Hello — this is your agent, speaking from your wrist.")
    end

    # 1 while the synthesizer is actively speaking — the honest runtime proof that
    # TTS started on the watch (audio session + AVSpeechSynthesizer working).
    def self.speaking : Int32
      UI::Speech.speaking? ? 1 : 0
    end

    # The COHESION loop: schedule a short (3s) local notification. When it fires
    # while the app is foregrounded, the native UNUserNotificationCenter delegate
    # calls back into Crystal → the HostBootstrap-registered on_foreground handler
    # → UI::Speech.speak(body). i.e. the agent buzzes your wrist AND reads it
    # aloud. The caller checks `speaking` a few seconds later (after delivery).
    def self.test_fg_speak : Nil
      initialize_runtime
      UI::Notifications.request_authorization(provisional: true)
      UI::Notifications.schedule(UI::NotificationRequest.new(
        title: "Coach",
        body: "Time to stand up and take a breath.",
        identifier: "voyager-fg-test",
        delay_seconds: 3.0, repeats: false, sound: true, thread_id: "voyager-coach",
      ))
    end

    # Drive a real agent reply through the REAL controller path (seed the compose
    # field + dispatch :send_message), with the voice mute pref set to `muted`.
    # Proves the header's mute toggle actually gates speech: muted → the agent reply
    # is NOT spoken; unmuted → it is. The caller checks `speaking` after a beat
    # (speech is async). Root the watch at :voyager-agent-chat.
    def self.test_voice_gate(muted : Int32) : Nil
      initialize_runtime
      Voyager.state.speak_replies = (muted == 0)
      UI::Speech.stop
      @@dispatcher.not_nil!.current_form_state.update("chat_message", "are you there?")
      Voyager.dispatch(:send_message)
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

  fun voyager_watch_test_nav : Void
    VoyagerWatchBridge.test_nav
  end

  fun voyager_watch_test_notif : Int32
    VoyagerWatchBridge.test_notif
  end

  fun voyager_watch_test_speak : Void
    VoyagerWatchBridge.test_speak
  end

  fun voyager_watch_speaking : Int32
    VoyagerWatchBridge.speaking
  end

  fun voyager_watch_test_fg_speak : Void
    VoyagerWatchBridge.test_fg_speak
  end

  fun voyager_watch_test_voice_gate(muted : Int32) : Void
    VoyagerWatchBridge.test_voice_gate(muted)
  end
{% end %}
