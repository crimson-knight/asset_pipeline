# Phase 6.10 + Phase 8D.1 — Voyager macOS host.
#
# Phase 6.10 shape: a NavigationCoordinator-driven AppKit app — initial
# build, install as NSWindow contentView, subscribe to `coord.on_change`,
# swap contentView on every push / pop / replace_root.
#
# Phase 8D.1 migration: user-intent callbacks now flow through
# `UI::ActionDispatcher`. The host:
#   1. Calls `VoyagerApp.bootstrap!` to register the 4 screens.
#   2. Creates a `UI::NavigationCoordinator` + `UI::AppKit::Renderer` +
#      session + flash + `UI::ActionDispatcher`.
#   3. Assigns `Voyager.dispatcher = dispatcher` so screen callback
#      closures route action refs through the dispatcher.
#   4. Calls `dispatcher.mount_screen(coord.current)` to seed the
#      mount-scoped FormState before the initial render.
#   5. Subscribes to `coord.on_change` with a renderer-only callback
#      that does NOT call mount_screen (per the brief's stack-policy
#      contract + spike pattern — the dispatcher's translate_result
#      already mounts before notify).
#
# Slug source: ENV["VOYAGER_ROOT_SLUG"] || ARGV[0] || "voyager-sign-in".
# Set VOYAGER_ROOT_SLUG=voyager-todos to skip the auth flow during
# manual verification.

require "../app"
require "../../../src/ui/renderers/appkit_renderer"

{% if flag?(:macos) %}
  ROOT_SLUG  = ENV["VOYAGER_ROOT_SLUG"]? || ARGV[0]? || "voyager-sign-in"
  APPEARANCE = ENV["VOYAGER_APPEARANCE"]? || ENV["HIG_APPEARANCE"]? || "light"

  # Window helper compiled into the binary at link time (see Makefile).
  lib LibWindowHelper
    fun hig_create_window(x : Float64, y : Float64, w : Float64, h : Float64, title : UInt8*) : Void*
    fun hig_create_window_with_min(
      x : Float64, y : Float64, w : Float64, h : Float64,
      min_w : Float64, min_h : Float64,
      title : UInt8*, appearance : UInt8*,
    ) : Void*
    fun hig_run_app(window : Void*) : Void
    fun objc_create_capture_window(width : Float64, height : Float64, appearance : UInt8*) : Void*
    fun objc_install_content_view(window : Void*, content_view : Void*) : Void
    fun objc_scroll_wrap(content_view : Void*) : Void*
    fun objc_capture_view_offscreen(window : Void*, output_path : UInt8*, width : Float64, height : Float64) : Int32
    fun objc_capture_window_to_png(window : Void*, output_path : UInt8*) : Int32
    fun objc_close_capture_window(window : Void*) : Void
    fun objc_run_loop_for(seconds : Float64) : Void
    # Track 2 — live window-resize → Crystal rebuild.
    fun objc_window_install_resize_observer(window : Void*, tag : UInt64) : Void
    fun objc_window_set_content_size(window : Void*, w : Float64, h : Float64) : Void
    fun objc_window_order_front(window : Void*) : Void
  end

  lib LibObjCBridgeVoyager
    fun objc_send_void_id(obj : Void*, sel : Void*, arg : Void*) : Void
    fun sel_registerName(name : UInt8*) : Void*
  end

  module VoyagerHost
    WINDOW_WIDTH  = 880.0
    WINDOW_HEIGHT = 640.0
    MIN_WIDTH     = 480.0
    MIN_HEIGHT    = 400.0

    CAPTURE_WIDTH  = (ENV["VOYAGER_CAPTURE_WIDTH"]?.try(&.to_f?) || 720.0)
    CAPTURE_HEIGHT = (ENV["VOYAGER_CAPTURE_HEIGHT"]?.try(&.to_f?) || 640.0)

    # GC-pinned references so the AppKit run loop doesn't collect the
    # Crystal-side state, coordinator, renderer, dispatcher, or active
    # NativeView. NONE carry default initializers — explicit assignment
    # in `run!` so the iOS class-init gap pattern is symmetric across
    # hosts (macOS doesn't suffer the gap; we keep the discipline so the
    # iOS bridge can lift this pattern in Phase 8D.2 unchanged).
    @@coord : UI::NavigationCoordinator? = nil
    @@renderer : UI::AppKit::Renderer? = nil
    @@dispatcher : UI::ActionDispatcher? = nil
    @@window_ptr : Void* = Pointer(Void).null
    @@set_content_sel : Void* = Pointer(Void).null
    @@active_native : UI::NativeView? = nil
    # Tracks whether we're on the capture-window pair (objc_install_content_view)
    # or the regular NSWindow path (setContentView: via objc_send_void_id).
    # Set in `run!` once the window is created.
    @@is_capture_path : Bool = false
    # Track 2 — last content width the tree was built against. Used to
    # coalesce the windowDidResize storm: a resize that doesn't change the
    # content width (e.g. a duplicate notification) skips the rebuild.
    @@last_content_width : Float64 = 0.0

    # Track 2 — fired by the NSWindow resize observer (via CallbackRegistry).
    # Re-runs build(ctx) for the current route so size-class-driven
    # decisions (column width, spacing, type scale authored through
    # DeviceMetrics#responsive) reflow live as the window resizes — the
    # piece that makes "the window resizes but nothing moves" actually move.
    def self.on_window_resized : Nil
      coord = @@coord
      return if coord.nil?
      w = UI::DesignTokens::DeviceMetrics.current.content_width_pt
      return if (w - @@last_content_width).abs < 1.0
      @@last_content_width = w
      rebuild_for(coord.current)
    end

    def self.install_view(view : UI::View) : Nil
      # Phase 12.C iter-4 (V1 fix Option A) — macOS doesn't currently
      # exhibit V1 (no .id()-bump equivalent in the host loop), but we
      # apply the same architectural pattern so the cross-platform
      # contract is symmetric. The macOS renderer was already
      # constructed once at startup, so we rebuild it per-install
      # with the reuse registry. The prior renderer is dropped; this
      # is acceptable because UI::Environment / DeviceMetrics installs
      # are idempotent.
      reuse_registry = {} of String => UI::NativeView
      if prior_for_reuse = @@active_native
        prior_for_reuse.walk_reactive_views do |reactive_view|
          if id = reactive_view.handle.presentation_identity
            reuse_registry[id] = reactive_view
          end
        end
      end

      renderer = UI::AppKit::Renderer.new(reuse_registry: reuse_registry)
      @@renderer = renderer
      native = renderer.render(view)

      # Extract reused NativeViews from prior tree so its GC pass
      # doesn't double-release shared NativeHandles.
      if prior_for_detach = @@active_native
        prior_for_detach.detach_reused!
      end

      # Phase 12.C — identity-aware cross-render presentation sweep
      # for ORPHANED handles. After detach, only orphans remain in
      # the prior tree; the sweep flips their bindings cleanly.
      UI::NativeView.dismiss_reactive_presentations!(@@active_native, fresh: native)

      @@active_native = native
      # Wrap the rendered content in a vertically-scrolling NSScrollView so
      # tall screens (e.g. the Component Gallery) scroll instead of being
      # compressed into the window and overlapping — the macOS parallel to
      # the iOS host's UIScrollView wrap. Short screens still fill the
      # viewport, so existing captures are unaffected. Falls back to the
      # raw content view if the wrap fails.
      content_ptr = native.handle.ptr!
      scroll_ptr = LibWindowHelper.objc_scroll_wrap(content_ptr)
      install_ptr = scroll_ptr.null? ? content_ptr : scroll_ptr
      if @@is_capture_path
        LibWindowHelper.objc_install_content_view(@@window_ptr, install_ptr)
      else
        LibObjCBridgeVoyager.objc_send_void_id(
          @@window_ptr, @@set_content_sel, install_ptr,
        )
      end
    end

    # Render the route the dispatcher just mounted (FormState already
    # swapped via translate_result's mount-before-notify ordering).
    def self.rebuild_for(route : UI::NavigationCoordinator::Route) : Nil
      dispatcher = @@dispatcher.not_nil!
      reg = VoyagerApp.registration_for(route.id)
      screen_class = reg.screen_class
      if screen_class.nil?
        placeholder = UI::Label.new("Unknown screen for route: #{route.id}")
        placeholder.accessibility_label = "Unknown route"
        install_view(placeholder.as(UI::View))
        return
      end

      # Build a fresh ScreenContext::Native from the dispatcher's live
      # FormState / session / flash / design_tokens / navigation. This
      # is the proven Phase 8B spike pattern
      # (samples/phase-08b-native-spike/src/spike_app.cr#rebuild_for).
      # action_params is empty at render time — it only carries values
      # during in-flight dispatches.
      ctx = UI::ScreenContext::Native.new(
        form_state: dispatcher.current_form_state,
        session: dispatcher.session,
        flash: dispatcher.flash,
        design_tokens: dispatcher.design_tokens,
        navigation: dispatcher.navigation,
        action_params: {} of String => String,
        # Phase 10D — thread dispatcher.platform so screens calling
        # `UI::WidgetRoute.resolve(intent_id, ctx)` get the platform-correct
        # widget. macOS resolves `:swipe_actions` to
        # `UI::InlineActionRow`.
        platform: dispatcher.platform,
        environment: dispatcher.environment,
      )
      view = screen_class.new.build(ctx)

      # Track 2 metric-contract instrumentation. Set VOYAGER_DEBUG_METRICS=1
      # to print the live DeviceMetrics the screen just authored against —
      # a unique grep token so capture/AX runs can assert the size class
      # tracks the actual window/capture width (the fix that makes narrow
      # windows reflow to the compact column). No-op when unset.
      if ENV["VOYAGER_DEBUG_METRICS"]?
        m = UI::DesignTokens::DeviceMetrics.current
        STDERR.puts "[VOYAGER_METRICS] width=#{m.content_width_pt} hsize=#{m.horizontal_size_class} compact=#{m.compact_horizontal?}"
      end

      install_view(view)
    end

    def self.run!
      # Phase 8D.1 — bootstrap registers all 4 screens. macOS doesn't
      # suffer the iOS class-init gap but we keep the call symmetric
      # with the spike + the iOS bridge (Phase 8D.2 will use the same
      # call).
      VoyagerApp.bootstrap!

      # Seed the singleton state so screens that read `Voyager.state`
      # see the same instance across all 4 routes.
      Voyager.state = Voyager::State.new

      coord = UI::NavigationCoordinator.new(Voyager.route_for_slug(ROOT_SLUG))
      renderer = UI::AppKit::Renderer.new
      session = UI::Session::InProcess.new
      flash = UI::Flash::InProcess.new

      dispatcher = UI::ActionDispatcher.new(
        app: VoyagerApp,
        navigation: coord,
        session: session,
        flash: flash,
        design_tokens: UI::DesignTokens::Tokens.default,
      )
      # Initial mount — bumps the dispatcher's mount_token + seeds
      # form_state from coord.current.params + swaps the renderer's
      # wire-time FormState. Must happen BEFORE the first render so
      # the TextField wire-time hook sees the new mount.
      dispatcher.mount_screen(coord.current)

      @@coord = coord
      @@renderer = renderer
      @@dispatcher = dispatcher

      # Phase 8D.1 — wire screens to dispatch through this host's
      # dispatcher.
      Voyager.dispatcher = dispatcher

      # Phase 8D.3b — capture-scenario hook. When the host launches with
      # VOYAGER_CAPTURE_SCENARIO set (driven by bin/capture_voyager_macos.sh),
      # walk state + coord + dispatcher into the target visual end state
      # BEFORE rebuild_for(coord.current) is called (either the capture
      # branch below or the interactive branch). No-op when unset.
      if scenario = ENV["VOYAGER_CAPTURE_SCENARIO"]?
        Voyager::CaptureScenarios.apply(scenario, Voyager.state, coord, dispatcher)
      end

      # Track 2 — headless resize-probe. VOYAGER_RESIZE_PROBE="460,900" creates
      # a real titled/resizable NSWindow at the first width, installs the live
      # resize observer, renders once, then programmatically resizes to the
      # second width and pumps the run loop so windowDidResize fires the
      # observer → on_window_resized → rebuild_for. With VOYAGER_DEBUG_METRICS=1
      # this prints two [VOYAGER_METRICS] lines (the second triggered ONLY by
      # the resize, no navigation) — proof the live-resize→rebuild path works
      # without needing a GUI session. No-op when unset.
      if probe = ENV["VOYAGER_RESIZE_PROBE"]?
        widths = probe.split(",").map(&.strip.to_f)
        w0 = widths[0]? || 460.0
        w1 = widths[1]? || 900.0
        h = (ENV["VOYAGER_CAPTURE_HEIGHT"]?.try(&.to_f?) || 720.0)
        window = LibWindowHelper.hig_create_window_with_min(
          120.0, 120.0, w0, h, MIN_WIDTH, MIN_HEIGHT,
          "Voyager".to_unsafe, APPEARANCE.to_unsafe,
        )
        @@window_ptr = window
        @@set_content_sel = LibObjCBridgeVoyager.sel_registerName("setContentView:".to_unsafe)
        @@is_capture_path = false
        resize_tag = UI::CallbackRegistry.register { VoyagerHost.on_window_resized }
        LibWindowHelper.objc_window_install_resize_observer(window, resize_tag)
        # Order the window front so DeviceMetrics resolves to it (not the screen).
        LibWindowHelper.objc_window_order_front(window)
        LibWindowHelper.objc_run_loop_for(0.2)
        STDERR.puts "[VOYAGER_RESIZE_PROBE] initial width=#{w0}"
        rebuild_for(coord.current)
        STDERR.puts "[VOYAGER_RESIZE_PROBE] resizing #{w0} -> #{w1}"
        LibWindowHelper.objc_window_set_content_size(window, w1, h)
        LibWindowHelper.objc_run_loop_for(0.4)
        STDERR.puts "[VOYAGER_RESIZE_PROBE] done"
        exit(0)
      end

      screenshot_path = ENV["VOYAGER_SCREENSHOT_PATH"]? || ENV["HIG_SCREENSHOT_PATH"]?
      if screenshot_path
        # Offscreen capture path — capture window is a Void** pair.
        window = LibWindowHelper.objc_create_capture_window(CAPTURE_WIDTH, CAPTURE_HEIGHT, APPEARANCE.to_unsafe)
        @@window_ptr = window
        @@is_capture_path = true

        rebuild_for(coord.current)
        LibWindowHelper.objc_run_loop_for(0.4)
        rc = LibWindowHelper.objc_capture_view_offscreen(
          window, screenshot_path.to_unsafe, CAPTURE_WIDTH, CAPTURE_HEIGHT,
        )
        LibWindowHelper.objc_close_capture_window(window)
        STDERR.puts "[voyager] screenshot rc=#{rc} -> #{screenshot_path}"
        exit(rc == 1 ? 0 : 1)
      end

      # Interactive path — titled NSWindow + setContentView:.
      title_str = "Voyager"
      appearance_arg = if ENV["VOYAGER_APPEARANCE"]? || ENV["HIG_APPEARANCE"]?
                         APPEARANCE.to_unsafe
                       else
                         Pointer(UInt8).null
                       end
      window = LibWindowHelper.hig_create_window_with_min(
        120.0, 120.0, WINDOW_WIDTH, WINDOW_HEIGHT,
        MIN_WIDTH, MIN_HEIGHT,
        title_str.to_unsafe, appearance_arg,
      )
      set_content = LibObjCBridgeVoyager.sel_registerName("setContentView:".to_unsafe)
      @@window_ptr = window
      @@set_content_sel = set_content
      @@is_capture_path = false

      # Initial render of the bootstrap route.
      rebuild_for(coord.current)

      # Track 2 — live window-resize → rebuild. Register a CallbackRegistry
      # Proc and attach it to this window's NSWindowDidResizeNotification so a
      # user dragging the window re-runs build(ctx) with the new size class.
      resize_tag = UI::CallbackRegistry.register { VoyagerHost.on_window_resized }
      LibWindowHelper.objc_window_install_resize_observer(window, resize_tag)

      # The reactive substrate: every dispatcher-routed Navigate / Pop /
      # ReplaceRoot fires `translate_result`, which calls mount_screen
      # FIRST (swapping FormState.current under the new token) and THEN
      # invokes the coord op that fires this on_change. The subscriber
      # here only RENDERS — no mount_screen call. Per brief Item 4 +
      # spike pattern.
      coord.on_change do |route|
        VoyagerHost.rebuild_for(route)
      end

      STDERR.puts "[voyager macos] launching with root slug=#{ROOT_SLUG} appearance=#{APPEARANCE}"
      LibWindowHelper.hig_run_app(window)
    end
  end

  VoyagerHost.run!
{% else %}
  STDERR.puts "samples/initiative-cross-platform-ui-voyager/macos/host.cr must be built with -Dmacos"
  exit 1
{% end %}
