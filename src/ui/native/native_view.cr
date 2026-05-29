# A rendered native view tree node: pairs a `NativeHandle` with its children to
# mirror the platform view hierarchy produced by a platform renderer.

require "./native_handle"
require "./callback_registry"
{% if flag?(:macos) || flag?(:ios) %}
  require "./swiftkit_bridge"
  require "./interaction_contracts"
{% end %}

module UI
  # A rendered native view tree node wrapping a platform-specific handle.
  #
  # `NativeView` is the output of a platform renderer (AppKit, UIKit, Android).
  # It forms a tree structure mirroring the native view hierarchy, with each
  # node owning:
  #
  # - A `NativeHandle` to the platform object (NSView, UIView, Android View)
  # - An array of child `NativeView` nodes
  # - An array of callback IDs registered via `CallbackRegistry`
  #
  # ## Lifecycle States
  #
  # ```
  # Created -> Attached -> Detached -> TornDown
  #                |                      ^
  #                +----------------------+
  #                  (teardown! from Attached)
  # ```
  #
  # - `Created`: The view has been constructed but not yet added to a parent.
  # - `Attached`: The view is part of an active native view hierarchy.
  # - `Detached`: The view was removed from its parent but not yet torn down.
  #   Resources are still held; the view could potentially be re-attached.
  # - `TornDown`: All resources have been released. The view is dead and
  #   must not be used.
  #
  # ## Deterministic Cleanup
  #
  # `teardown!` performs post-order recursive cleanup:
  #
  # 1. Tear down all children (depth-first, children before parent)
  # 2. Unregister all callbacks from `CallbackRegistry`
  # 3. Release the `NativeHandle`
  # 4. Transition to `TornDown` state
  #
  # This ensures native child views are removed before their parent, which
  # is required by both AppKit and Android view hierarchies.
  class NativeView
    enum State
      Created
      Attached
      Detached
      TornDown
    end

    # The native platform object handle.
    getter handle : NativeHandle

    # Ordered list of child native views.
    getter children : Array(NativeView)

    # Current lifecycle state.
    getter state : State

    # IDs of callbacks registered via `CallbackRegistry` that belong to
    # this view. Cleaned up during `teardown!`.
    @callback_ids : Array(UInt64)

    def initialize(@handle : NativeHandle, @children : Array(NativeView) = [] of NativeView)
      @state = State::Created
      @callback_ids = [] of UInt64
    end

    # Add a child to this view's children array.
    #
    # Raises if this view has been torn down.
    def add_child(child : NativeView) : Nil
      check_not_torn_down!
      @children << child
    end

    # Remove a specific child from this view's children array.
    #
    # Returns `true` if the child was found and removed, `false` otherwise.
    # Does NOT tear down the removed child -- the caller is responsible for
    # that if the child is no longer needed.
    def remove_child(child : NativeView) : Bool
      check_not_torn_down!
      deleted = false
      @children.reject! do |c|
        if c.same?(child)
          deleted = true
          true
        else
          false
        end
      end
      deleted
    end

    # Remove all children from this view's children array.
    #
    # Does NOT tear down the removed children -- the caller is responsible
    # for that if the children are no longer needed.
    def remove_all_children : Nil
      check_not_torn_down!
      @children.clear
    end

    # Transition this view to the `Attached` state.
    #
    # Raises if the view is already torn down.
    def attach! : Nil
      check_not_torn_down!
      @state = State::Attached
    end

    # Transition this view to the `Detached` state.
    #
    # Raises if the view is already torn down.
    def detach! : Nil
      check_not_torn_down!
      @state = State::Detached
    end

    # Register a callback `Proc` in the `CallbackRegistry` and track its
    # ID for cleanup during `teardown!`.
    #
    # Returns the callback ID for passing to the native side.
    def register_callback(callback : Proc(Nil)) : UInt64
      check_not_torn_down!
      id = CallbackRegistry.register(callback)
      @callback_ids << id
      id
    end

    # Track a callback ID that was registered directly against CallbackRegistry.
    #
    # This is useful for typed callback registries that return IDs but do not
    # route through `register_callback`.
    def track_callback_id(id : UInt64) : UInt64
      check_not_torn_down!
      @callback_ids << id
      id
    end

    # Register a callback block and track its ID for cleanup during `teardown!`.
    def register_callback(&block : -> Nil) : UInt64
      register_callback(block)
    end

    # Perform post-order recursive cleanup of this view and all descendants.
    #
    # 1. Recursively tears down all children (depth-first)
    # 2. Clears the children array
    # 3. Unregisters all tracked callbacks from `CallbackRegistry`
    # 4. Releases the `NativeHandle`
    # 5. Transitions to `TornDown` state
    #
    # This method is idempotent: calling it on an already-torn-down view
    # is a safe no-op.
    def teardown! : Nil
      return if @state.torn_down?

      # Post-order: children first
      @children.each(&.teardown!)
      @children.clear

      # Unregister all callbacks
      CallbackRegistry.unregister(@callback_ids)
      @callback_ids.clear

      # Release the native handle
      @handle.release!

      @state = State::TornDown
    end

    # GC safety net. If the view was never explicitly torn down, attempt
    # to clean up. Always prefer calling `teardown!` explicitly.
    def finalize
      return if @state.torn_down?
      # During finalization, children may have already been collected.
      # Only release our own handle and callbacks.
      CallbackRegistry.unregister(@callback_ids) unless @callback_ids.empty?
      @handle.release! unless @handle.released?
      @state = State::TornDown
    end

    # Returns `true` if the view has been torn down.
    def torn_down? : Bool
      @state.torn_down?
    end

    # Phase 12.C — depth-first iterative walk that yields every
    # NativeHandle in this subtree carrying a non-nil `reactive_kind`.
    # Used by the renderer-side cross-render sweep
    # (`NativeView.dismiss_reactive_presentations!`).
    #
    # Iterative (not recursive) because Crystal forbids recursive
    # yields — the block would inline indefinitely. Yields directly
    # inside the pop loop so no result array is materialised; the only
    # allocation per call is the work-stack.
    #
    # Torn-down nodes are pruned (their subtrees are skipped) because
    # their handles are released — dispatching through them would
    # crash.
    def walk_reactive_handles(& : NativeHandle ->) : Nil
      return if @state.torn_down?
      stack = [self]
      until stack.empty?
        node = stack.pop
        next if node.state.torn_down?
        h = node.handle
        yield h if h.reactive_kind && !h.released?
        node.children.reverse_each { |c| stack << c }
      end
    end

    # Phase 12.C — cross-render reactive-presentation sweep (Path A
    # of the V1 lifecycle fix, presentation-lifecycle-contract C1).
    #
    # Hosts that hold a `NativeView` across re-render calls (the
    # Voyager iOS bridge's `@@last_native`, the macOS host's
    # `@@active_native`) MUST call this AFTER building the new
    # render's tree but BEFORE swapping the host root. Pass BOTH the
    # prior tree (whose orphaned presentations need binding-flips)
    # AND the fresh tree (so surviving identities are spared).
    #
    # Identity-aware semantics (Codex P12.C iter-1 BLOCKER 2):
    #   * If a `:sheet` (or `:confirmation_dialog`) handle in `prior`
    #     has a `presentation_identity` that ALSO exists in `fresh`
    #     with a non-nil state_handle, the handle is considered a
    #     CONTINUING presentation — we leave its binding alone so an
    #     unrelated Rerender (e.g., a checkbox toggle while the
    #     editor sheet is open) does NOT close the sheet.
    #   * If the identity is missing from `fresh` (or `fresh` is nil),
    #     the handle is ORPHANED — we flip its binding to false so
    #     SwiftUI sees `cause=binding-dismiss` instead of
    #     `cause=tree-removal` when the host swap discards the old
    #     UIView.
    #
    # Why a Rerender on a continuing presentation still works:
    #   The OLD UIHostingView still gets torn out by the host swap
    #   (V1 hazard for the surviving identity), but the new tree
    #   mounts a fresh hosting view at the same identity. The visual
    #   transition is a re-present rather than a dismiss; this is a
    #   known limitation that proper view reconciliation (state-handle
    #   reuse across renders) would eliminate. Logged for Phase 12.D
    #   follow-up.
    #
    # Idempotent on first-render (`prior == nil`) and on already-
    # dismissed bindings.
    #
    # Main-thread invariant: the underlying `apsk_*_set_presented`
    # bridges route writes through `apskMainAsync`, which fast-paths
    # synchronously on the main thread and dispatches async otherwise.
    # Callers SHOULD invoke this on the main thread; otherwise the
    # binding flip may land AFTER the host swap, defeating the fix.
    # Both Voyager hosts (iOS via UIViewRepresentable, macOS via the
    # AppKit run loop) are main-threaded.
    def self.dismiss_reactive_presentations!(prior : NativeView?, fresh : NativeView? = nil) : Nil
      return if prior.nil?
      {% if flag?(:macos) || flag?(:ios) %}
        surviving = collect_surviving_identities(fresh)
        prior.walk_reactive_handles do |handle|
          state_ptr = handle.state_handle
          next if state_ptr.nil?
          identity = handle.presentation_identity
          # Skip identities the new tree still presents — those are
          # CONTINUING presentations, not orphans.
          next if identity && surviving.includes?(identity)

          case handle.reactive_kind
          when :sheet
            LibSwiftKitBridge.apsk_sheet_set_presented(state_ptr, 0)
            UI::InteractionContracts.emit_for(
              "Sheet",
              "programmatic-dismiss-on-rerender",
              identity || handle.label,
              reason: "cross-render-sweep",
            )
          when :confirmation_dialog
            LibSwiftKitBridge.apsk_confirmation_dialog_set_presented(state_ptr, 0)
            UI::InteractionContracts.emit_for(
              "ConfirmationDialog",
              "programmatic-dismiss-on-rerender",
              identity || handle.label,
              reason: "cross-render-sweep",
            )
          else
            # Unknown reactive_kind — silently skip; future
            # presentations (Popover / Alert) extend the case above.
          end
        end
      {% end %}
      nil
    end

    # Build the set of `presentation_identity` values still presented
    # by the fresh tree. A handle qualifies as "surviving" when:
    #   * its `reactive_kind` is a presentation kind
    #   * it carries a non-nil `presentation_identity`
    #   * its `state_handle` is non-nil (i.e. the reactive entry was
    #     actually invoked — defensive)
    #
    # Callers compare a prior handle's identity against this set to
    # decide whether to flip its binding.
    private def self.collect_surviving_identities(fresh : NativeView?) : Set(String)
      surviving = Set(String).new
      return surviving if fresh.nil?
      fresh.walk_reactive_handles do |handle|
        next unless handle.reactive_kind
        next if handle.state_handle.nil?
        if id = handle.presentation_identity
          surviving.add(id)
        end
      end
      surviving
    end

    private def check_not_torn_down! : Nil
      if @state.torn_down?
        raise "NativeView has been torn down and cannot be modified"
      end
    end
  end
end
