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
    # Phase 6.10 Rem 4 — suppress the Swift route-changed callback
    # during the initial coord/slug resync (see render_slug). Without
    # this guard, replace_root → notify → Swift cb → render_slug →
    # resync loop fires recursively.
    @@suppress_route_changed = false

    def self.initialize_runtime
      return if @@initialized
      GC.init

      # Phase 6.10 Rem 3 — iOS class-init gap: bootstrap the Crystal
      # runtime subsystems that `__crystal_main`'s `init_runtime`
      # normally calls but the iOS embedding skips (because
      # `_main` is unexported in `build_crystal_lib.sh`).
      #
      # Without these three calls, any `Crystal::once`-guarded constant
      # (e.g. `String::CHAR_TO_DIGIT` used by `String#to_i?`) walks an
      # uninitialised `Thread::LinkedList(Fiber)` and SIGSEGVs at
      # `Thread::LinkedList(Fiber)#push` (KERN_INVALID_ADDRESS at 0x18).
      # Symptom in Rem 2: launching with
      # `VOYAGER_ROOT_SLUG=voyager-todo-editor` crashed silently inside
      # `Voyager.build_route` because the editor's
      # `(route.params[:id]? || "0").to_i?` triggered a const_read.
      # Crash trace preserved at
      # `~/Library/Logs/DiagnosticReports/VoyagerDemo-2026-05-23-155642.ips`.
      #
      # See `src/crystal/main.cr#init_runtime` for the upstream
      # invariant; the comment there reads:
      #   "`__crystal_once` directly or indirectly depends on `Fiber`
      #   and `Thread` so we explicitly initialize their class vars,
      #   then init crystal/once".
      #
      # This is the systematic fix the
      # `project_crystal_ios_class_init_gap` memory item flagged as
      # "Phase 5+ should address this systematically: either patch the
      # iOS embedding to explicitly call the missing init functions ..."
      Thread.init
      Fiber.init
      Crystal::Once.init

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
      # Phase 6.11 Item 1 — brand override removed. Renderer carries
      # `UI::DesignTokens::Tokens.default` already; no per-host override.

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
        if @@suppress_route_changed
          # Initial resync — Swift callback intentionally suppressed.
        elsif !cb.nil? && !buf.nil?
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

      # Phase 6.10 Rem 1 — fresh renderer per render call to match
      # Cascade's proven-working pattern. Reusing a single renderer
      # across slug changes produced inverted-order / collapsed-field
      # layouts on iOS even though the same screen authoring rendered
      # correctly with a fresh renderer. The exact root cause appears
      # to be UIHostingController state inside SwiftKit facades; a new
      # renderer instance defensively rebuilds every facade chain.
      renderer = UI::UIKit::Renderer.new
      # Phase 6.11 Item 1 — brand override removed. Renderer carries
      # `UI::DesignTokens::Tokens.default` already; no per-host override.

      route = Voyager.route_for_slug(slug)
      # Phase 6.10 Rem 4 (Item 1) — coord/slug sync invariant.
      #
      # When Swift launches with VOYAGER_ROOT_SLUG=voyager-todos, the
      # Crystal coord is still at its constructor default (:sign_in).
      # Without resync, the user's Save → coord.pop returns to
      # :sign_in instead of :todos, and the new todo never gets
      # visible because we land on the wrong screen.
      #
      # The previous logic only synced "if no Swift callback yet" —
      # but the callback gets registered BEFORE the first render
      # (VoyagerBridge.initialize() calls both routines), so the
      # branch never fired and the coord stayed misaligned.
      #
      # New rule: if the coord is at depth=1 (just the constructor
      # root) AND the requested slug doesn't match, treat this call as
      # a first-time sync from the Swift launch arg — replace the
      # root. Guard with `@@suppress_route_changed` so the resulting
      # notify doesn't fire the Swift callback (which would loop us
      # back into render_slug for the same slug we just synced).
      if coord.current.id != route.id && coord.depth == 1
        @@suppress_route_changed = true
        coord.replace_root(route)
        @@suppress_route_changed = false
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
