# Phase 6.10 — Voyager iOS bridge — exposed via build_crystal_lib.sh
# as libvoyager.a.
#
# C ABI:
#   void  voyager_init(void)
#       — must be called once before any render call. Seeds Crystal
#         probe singletons + builds the shared NavigationCoordinator
#         + State, both as INSTANCE state pinned in a module class
#         var (no class-var initializers — per the iOS class-init gap
#         memory item; we explicitly assign in voyager_init, never via
#         a class-var default value with side effects).
#
#   void* voyager_render(const char* slug)
#       — Builds a UI::View for the given slug (overrides any Crystal-
#         side current route; Swift drives the visible slug via the
#         @State binding). Renders via UIKit::Renderer and returns the
#         retained UIView*. Swift takes ownership via
#         takeRetainedValue().
#
#   const char* voyager_current_slug(void)
#       — Returns the slug-form of `coord.current.id` as a NUL-terminated
#         C string. The pointer is to a stable Crystal-managed buffer;
#         Swift may use it immediately but must not retain past the next
#         Crystal call. Used by the SwiftUI re-render trampoline.
#
#   void voyager_register_route_changed_callback(void (*cb)(const char*))
#       — Registers a C-callable Swift function pointer that Crystal
#         invokes inside coord.on_change with the new slug. This is the
#         runtime-navigation bridge: tapping a Crystal-rendered button
#         calls coord.push(...), which fires the registered callback,
#         which trips a Swift @State update, which causes SwiftUI to
#         re-render via voyager_render(new_slug).
#
# This file is the iOS-only twin of
# samples/initiative-cross-platform-ui-demo/ios/bridge.cr; both share
# the same cross-compile pattern documented in
# samples/initiative-cross-platform-ui-demo/ios/build_crystal_lib.sh.

{% if flag?(:ios) %}

  require "../app"
  require "../../../src/ui/renderers/uikit_renderer"
  require "../../../src/ui/probes"

  module VoyagerBridge
    # Mirror Cascade's bridge: instance state held in module class
    # variables, but NO initializer side effects — explicit assignment
    # in initialize_runtime so the iOS class-init gap can't strand any
    # of these as nil.
    # IMPORTANT: NONE of these class vars carry an initializer with side
    # effects (no `= Bytes.new(64)`, no `= [] of ...`). The iOS class-init
    # gap (see `project_crystal_ios_class_init_gap` memory) silently
    # SKIPS class-var initializers when _main is hidden for Swift @main,
    # so any allocation that should happen at module load must happen
    # inside `initialize_runtime` (which we call explicitly from
    # voyager_init). Nilable defaults (`= nil`) are safe — the
    # underlying field is just a tagged nil pointer.
    @@initialized = false
    @@state : Voyager::State? = nil
    @@coord : UI::NavigationCoordinator? = nil
    @@renderer : UI::UIKit::Renderer? = nil
    @@last_native : UI::NativeView? = nil
    @@current_slug_buf : Bytes? = nil
    @@swift_route_changed_cb : (LibC::Char* -> Void)? = nil

    def self.initialize_runtime
      return if @@initialized
      GC.init
      UI::Probes::DismissProbe.reset
      UI::Probes::ToggleProbe.reset
      UI::Probes::SliderProbe.reset
      UI::Probes::TapProbe.reset
      UI::Probes::FormRowProbe.reset
      UI::Probes::RuntimeOverrideProbe.reset

      # Allocate the slug buffer here (NOT as a class-var default) so the
      # iOS class-init gap can't strand it as nil. 64 bytes accommodates
      # the longest known Voyager slug (~"voyager-todo-editor" = 19) with
      # huge headroom for future routes.
      @@current_slug_buf = Bytes.new(64)

      state = Voyager::State.new
      coord = UI::NavigationCoordinator.new(
        UI::NavigationCoordinator::Route.new(:sign_in)
      )
      renderer = UI::UIKit::Renderer.new
      renderer.design_tokens = Voyager.brand_tokens

      # The reactive substrate: when ANY Crystal code (a tap handler
      # inside a rendered button, the sign-in submit, the settings
      # back action) calls coord.push/pop, this callback fires and we
      # hop into Swift via the registered route-changed C callback. The
      # Swift side then trips its @State binding, which re-runs
      # voyager_render(new_slug) and SwiftUI swaps the hosted UIView.
      coord.on_change do |route|
        slug = Voyager.slug_for_route_id(route.id)
        copy_slug_to_buf(slug)
        cb = @@swift_route_changed_cb
        buf = @@current_slug_buf
        if !cb.nil? && !buf.nil?
          cb.call(buf.to_unsafe.as(LibC::Char*))
        end
      end

      @@state = state
      @@coord = coord
      @@renderer = renderer
      copy_slug_to_buf(Voyager.slug_for_route_id(coord.current.id))
      @@initialized = true
    end

    private def self.copy_slug_to_buf(slug : String) : Nil
      buf = @@current_slug_buf
      return if buf.nil? # initialize_runtime always allocates this; guard for safety
      bytes = slug.to_slice
      n = Math.min(bytes.size, buf.size - 1)
      n.times { |i| buf[i] = bytes[i] }
      buf[n] = 0_u8
    end

    def self.current_slug_ptr : LibC::Char*
      initialize_runtime
      @@current_slug_buf.not_nil!.to_unsafe.as(LibC::Char*)
    end

    def self.register_route_changed(cb : LibC::Char* -> Void) : Nil
      @@swift_route_changed_cb = cb
    end

    # Build + render the requested slug. The slug Swift passes is the
    # source of truth — Crystal does NOT override it from the
    # coordinator's current state, because Swift may be requesting a
    # slug that the coordinator already moved past (e.g. SwiftUI may
    # batch state changes). Voyager.build_route operates from the
    # shared `state` so any prior coord mutations (state.hide_completed
    # toggling, etc.) are honored.
    def self.render_slug(slug : String) : UI::NativeView
      initialize_runtime
      state = @@state.not_nil!
      coord = @@coord.not_nil!
      renderer = @@renderer.not_nil!

      route = Voyager.route_for_slug(slug)
      # Keep the coordinator's idea of "current" in sync with what
      # Swift is rendering. If Swift requested a slug that doesn't
      # match the coord's current route (e.g. fresh launch + Swift
      # decides to show :sign_in but the coord says :sign_in already
      # — no-op), we replace_root only when truly mismatched AND we
      # use a guard to avoid re-firing on_change while we're already
      # responding to a route change.
      if coord.current.id != route.id
        # We use replace_root deliberately so we don't grow the stack
        # on every Swift-driven re-render. The Crystal-side coord.push
        # from inside button handlers is what builds the real
        # navigation stack; this branch is only for the initial
        # render path.
        coord.replace_root(route) if @@swift_route_changed_cb.nil?
      end

      view = Voyager.build_route(state, coord, route)
      view.accessibility_label = "voyager-root-#{slug}" if view.accessibility_label.to_s.empty?
      view.test_id = "voyager-root-#{slug}" if view.test_id.to_s.empty?
      native = renderer.render(view)
      @@last_native = native
      native
    end
  end

  # ---------------------------------------------------------------------------
  # C ABI exports
  # ---------------------------------------------------------------------------

  fun voyager_init : Void
    VoyagerBridge.initialize_runtime
  end

  fun voyager_render(slug_ptr : LibC::Char*) : Void*
    VoyagerBridge.initialize_runtime
    slug = String.new(slug_ptr)
    native = VoyagerBridge.render_slug(slug)
    native.handle.ptr!
  end

  fun voyager_current_slug : LibC::Char*
    VoyagerBridge.current_slug_ptr
  end

  fun voyager_register_route_changed_callback(cb : LibC::Char* -> Void) : Void
    VoyagerBridge.register_route_changed(cb)
  end

{% end %}
