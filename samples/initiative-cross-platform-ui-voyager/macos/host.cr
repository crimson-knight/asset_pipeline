# Phase 6.10 — Voyager macOS host.
#
# A NavigationCoordinator-driven AppKit app: builds the initial route's
# view, installs it as the NSWindow contentView, then subscribes to
# `coord.on_change` so that every push / pop / replace_root call
# triggers a rebuild + setContentView swap. This is the macOS twin of
# the iOS SwiftUI @State trampoline pattern.
#
# Slug source: ENV["VOYAGER_ROOT_SLUG"] || ARGV[0] || "voyager-sign-in".
# Set VOYAGER_ROOT_SLUG=voyager-todos to skip the auth flow during
# manual verification.
#
# Build: `make -C samples/initiative-cross-platform-ui-voyager macos`.
# That target compiles the asset_pipeline ObjC bridge, the
# AssetPipelineSwiftKit Swift facade, and the reused window_helper.m
# before `crystal-alpha build -Dmacos` links them together.

require "../app"
require "../../../src/ui/renderers/appkit_renderer"

{% if flag?(:macos) %}
  ROOT_SLUG  = ENV["VOYAGER_ROOT_SLUG"]? || ARGV[0]? || "voyager-sign-in"
  APPEARANCE = ENV["VOYAGER_APPEARANCE"]? || ENV["HIG_APPEARANCE"]? || "light"

  # Window helper compiled into the binary at link time (see Makefile).
  # Same window_helper.m the Cascade host uses — verbatim reuse.
  lib LibWindowHelper
    fun hig_create_window(x : Float64, y : Float64, w : Float64, h : Float64, title : UInt8*) : Void*
    fun hig_run_app(window : Void*) : Void
    fun objc_create_capture_window(width : Float64, height : Float64, appearance : UInt8*) : Void*
    fun objc_install_content_view(window : Void*, content_view : Void*) : Void
    fun objc_capture_view_offscreen(window : Void*, output_path : UInt8*, width : Float64, height : Float64) : Int32
    fun objc_capture_window_to_png(window : Void*, output_path : UInt8*) : Int32
    fun objc_close_capture_window(window : Void*) : Void
    fun objc_run_loop_for(seconds : Float64) : Void
  end

  lib LibObjCBridgeVoyager
    fun objc_send_void_id(obj : Void*, sel : Void*, arg : Void*) : Void
    fun sel_registerName(name : UInt8*) : Void*
  end

  module VoyagerHost
    WINDOW_WIDTH  = 880.0
    WINDOW_HEIGHT = 720.0

    CAPTURE_WIDTH  = 720.0
    CAPTURE_HEIGHT = 640.0

    # GC-pinned references so the AppKit run loop doesn't collect the
    # Crystal-side state, coordinator, renderer, or active NativeView.
    # Hosted as instance state on the module's singleton via @@ class
    # vars only after explicit initialisation (no class-var initializers
    # — per I-9 + the iOS class-init gap memory; on macOS the gap is
    # absent but we keep the pattern symmetric across hosts).
    @@state : Voyager::State? = nil
    @@coord : UI::NavigationCoordinator? = nil
    @@renderer : UI::AppKit::Renderer? = nil
    @@window_ptr : Void* = Pointer(Void).null
    @@set_content_sel : Void* = Pointer(Void).null
    @@active_native : UI::NativeView? = nil

    def self.install_view(view : UI::View) : Nil
      renderer = @@renderer.not_nil!
      native = renderer.render(view)
      @@active_native = native # pin the new tree
      LibObjCBridgeVoyager.objc_send_void_id(@@window_ptr, @@set_content_sel, native.handle.ptr!)
    end

    def self.rebuild_for(route : UI::NavigationCoordinator::Route) : Nil
      state = @@state.not_nil!
      coord = @@coord.not_nil!
      view = Voyager.build_route(state, coord, route)
      install_view(view)
    end

    def self.run!
      state = Voyager::State.new
      coord = UI::NavigationCoordinator.new(
        Voyager.route_for_slug(ROOT_SLUG)
      )
      renderer = UI::AppKit::Renderer.new
      renderer.design_tokens = Voyager.brand_tokens

      @@state = state
      @@coord = coord
      @@renderer = renderer

      # Build the initial view BEFORE creating the window so the window
      # always has a content view installed at first paint.
      initial_view = Voyager.build_route(state, coord, coord.current)
      initial_native = renderer.render(initial_view)
      @@active_native = initial_native

      screenshot_path = ENV["VOYAGER_SCREENSHOT_PATH"]? || ENV["HIG_SCREENSHOT_PATH"]?
      if screenshot_path
        # Offscreen capture path — mirrors Cascade's offscreen capture.
        title = "Voyager: #{ROOT_SLUG} (#{APPEARANCE}) capture"
        window = LibWindowHelper.objc_create_capture_window(CAPTURE_WIDTH, CAPTURE_HEIGHT, APPEARANCE.to_unsafe)
        LibWindowHelper.objc_install_content_view(window, initial_native.handle.ptr!)
        LibWindowHelper.objc_run_loop_for(0.4)
        rc = LibWindowHelper.objc_capture_view_offscreen(
          window, screenshot_path.to_unsafe, CAPTURE_WIDTH, CAPTURE_HEIGHT,
        )
        LibWindowHelper.objc_close_capture_window(window)
        STDERR.puts "[voyager] screenshot rc=#{rc} -> #{screenshot_path}"
        exit(rc == 1 ? 0 : 1)
      end

      # Interactive path — open a titled window and run the AppKit loop.
      title_str = "Voyager"
      window = LibWindowHelper.hig_create_window(120.0, 120.0, WINDOW_WIDTH, WINDOW_HEIGHT, title_str.to_unsafe)
      set_content = LibObjCBridgeVoyager.sel_registerName("setContentView:".to_unsafe)
      @@window_ptr = window
      @@set_content_sel = set_content

      # Install the initial view via setContentView: before subscribing —
      # subsequent on_change fires reuse install_view().
      LibObjCBridgeVoyager.objc_send_void_id(window, set_content, initial_native.handle.ptr!)

      # The reactive substrate: every NavigationCoordinator mutation
      # (push / pop / replace_root / pop_to_root) fires this callback
      # with the new visible route. The host rebuilds the view from the
      # SHARED state + the new route and swaps it in via setContentView:.
      # This is the runtime-navigation invariant Phase 6.10 ships.
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
