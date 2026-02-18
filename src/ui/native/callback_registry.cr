module UI
  # Module-level registry that prevents Crystal `Proc` closures from being
  # garbage collected while native code holds references to them.
  #
  # ## Problem
  #
  # When Crystal passes a `Proc` as a C function pointer (e.g., to the ObjC
  # target-action mechanism or JNI callback bridge), BoehmGC may collect the
  # closure if no Crystal-side reference remains. This causes a use-after-free
  # crash when the native side later invokes the callback.
  #
  # ## Solution
  #
  # `CallbackRegistry` holds a strong reference to every registered `Proc` in
  # a module-level `Hash`. Each registration returns a unique `UInt64` ID that
  # the native side stores. When the native callback fires, it passes the ID
  # back to Crystal, which looks up and invokes the live `Proc`.
  #
  # ## Lifecycle
  #
  # 1. Register a callback: `id = CallbackRegistry.register(proc)`
  # 2. Pass `id` to the native side (stored in SEL name, JNI callback ID, etc.)
  # 3. Native fires: calls `crystal_ui_callback_dispatch(id)` -> `CallbackRegistry.call(id)`
  # 4. On teardown: `CallbackRegistry.unregister(id)` removes the strong reference
  #
  # ## Thread Safety
  #
  # The `@@next_id` counter uses `Atomic(UInt64)` for safe concurrent ID generation.
  # The `@@callbacks` hash is NOT thread-safe; all registration/unregistration/calls
  # should happen on the main thread (which is the standard model for UI callbacks).
  module CallbackRegistry
    @@callbacks = Hash(UInt64, Proc(Nil)).new
    @@next_id = Atomic(UInt64).new(1_u64)

    # Register a callback proc and return its unique ID.
    #
    # The proc is held by strong reference until `unregister` is called.
    def self.register(callback : Proc(Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@callbacks[id] = callback
      id
    end

    # Register a callback block and return its unique ID.
    #
    # Convenience overload that wraps a block in a Proc.
    def self.register(&block : -> Nil) : UInt64
      register(block)
    end

    # Invoke the callback registered under the given ID.
    #
    # If the ID is not found (e.g., it was already unregistered), this is
    # a safe no-op. This prevents crashes if a native callback fires after
    # the Crystal side has torn down.
    def self.call(id : UInt64) : Nil
      @@callbacks[id]?.try(&.call)
    end

    # Remove the callback registered under the given ID.
    #
    # After this call, the `Proc` is eligible for GC and the ID will no
    # longer resolve. Safe to call with an ID that was already unregistered.
    def self.unregister(id : UInt64) : Nil
      @@callbacks.delete(id)
    end

    # Remove multiple callbacks by their IDs.
    #
    # Convenience method for bulk cleanup during `NativeView#teardown!`.
    def self.unregister(ids : Array(UInt64)) : Nil
      ids.each { |id| @@callbacks.delete(id) }
    end

    # Returns the number of currently registered callbacks.
    def self.size : Int32
      @@callbacks.size
    end

    # Remove all registered callbacks.
    #
    # Intended for use in test cleanup (`Spec.after_each`). Do NOT call
    # this in production code -- use `unregister` for targeted cleanup.
    def self.clear : Nil
      @@callbacks.clear
      @@next_id = Atomic(UInt64).new(1_u64)
    end
  end
end
