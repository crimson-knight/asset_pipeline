# C-exported callback for the CrystalActionDispatcher ObjC class.
# Called from ObjC when a button's action fires: dispatch: -> crystal_ui_callback_dispatch(tag)
fun crystal_ui_callback_dispatch(tag : UInt64) : Void
  UI::CallbackRegistry.call(tag)
end

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
    # Existing void callbacks (button taps)
    @@callbacks = Hash(UInt64, Proc(Nil)).new

    # String callbacks (text field changes)
    @@string_callbacks = Hash(UInt64, Proc(String, Nil)).new

    # Bool callbacks (toggle changes)
    @@bool_callbacks = Hash(UInt64, Proc(Bool, Nil)).new

    # Float64 callbacks (slider changes)
    @@float_callbacks = Hash(UInt64, Proc(Float64, Nil)).new

    # Int32 callbacks (picker/segmented changes)
    @@int_callbacks = Hash(UInt64, Proc(Int32, Nil)).new

    # Time callbacks (date/time picker changes)
    @@time_callbacks = Hash(UInt64, Proc(Time, Nil)).new

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

    # Register a String callback proc and return its unique ID.
    def self.register_string(callback : Proc(String, Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@string_callbacks[id] = callback
      id
    end

    # Invoke the String callback registered under the given ID.
    def self.call_string(id : UInt64, value : String) : Nil
      @@string_callbacks[id]?.try(&.call(value))
    end

    # Register a Bool callback proc and return its unique ID.
    def self.register_bool(callback : Proc(Bool, Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@bool_callbacks[id] = callback
      id
    end

    # Invoke the Bool callback registered under the given ID.
    def self.call_bool(id : UInt64, value : Bool) : Nil
      @@bool_callbacks[id]?.try(&.call(value))
    end

    # Register a Float64 callback proc and return its unique ID.
    def self.register_float(callback : Proc(Float64, Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@float_callbacks[id] = callback
      id
    end

    # Invoke the Float64 callback registered under the given ID.
    def self.call_float(id : UInt64, value : Float64) : Nil
      @@float_callbacks[id]?.try(&.call(value))
    end

    # Register an Int32 callback proc and return its unique ID.
    def self.register_int(callback : Proc(Int32, Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@int_callbacks[id] = callback
      id
    end

    # Invoke the Int32 callback registered under the given ID.
    def self.call_int(id : UInt64, value : Int32) : Nil
      @@int_callbacks[id]?.try(&.call(value))
    end

    # Register a Time callback proc and return its unique ID.
    def self.register_time(callback : Proc(Time, Nil)) : UInt64
      id = @@next_id.add(1_u64)
      @@time_callbacks[id] = callback
      id
    end

    # Invoke the Time callback registered under the given ID.
    def self.call_time(id : UInt64, value : Time) : Nil
      @@time_callbacks[id]?.try(&.call(value))
    end

    # Remove the callback registered under the given ID.
    #
    # After this call, the `Proc` is eligible for GC and the ID will no
    # longer resolve. Safe to call with an ID that was already unregistered.
    # Checks all typed hashes.
    def self.unregister(id : UInt64) : Nil
      @@callbacks.delete(id)
      @@string_callbacks.delete(id)
      @@bool_callbacks.delete(id)
      @@float_callbacks.delete(id)
      @@int_callbacks.delete(id)
      @@time_callbacks.delete(id)
    end

    # Remove multiple callbacks by their IDs.
    #
    # Convenience method for bulk cleanup during `NativeView#teardown!`.
    def self.unregister(ids : Array(UInt64)) : Nil
      ids.each { |id| unregister(id) }
    end

    # Returns the number of currently registered callbacks across all typed hashes.
    def self.size : Int32
      @@callbacks.size + @@string_callbacks.size + @@bool_callbacks.size + @@float_callbacks.size + @@int_callbacks.size + @@time_callbacks.size
    end

    # Remove all registered callbacks from all typed hashes.
    #
    # Intended for use in test cleanup (`Spec.after_each`). Do NOT call
    # this in production code -- use `unregister` for targeted cleanup.
    def self.clear : Nil
      @@callbacks.clear
      @@string_callbacks.clear
      @@bool_callbacks.clear
      @@float_callbacks.clear
      @@int_callbacks.clear
      @@time_callbacks.clear
      @@next_id = Atomic(UInt64).new(1_u64)
    end
  end
end
