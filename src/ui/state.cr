# Type-safe reactive state container (`UI::State(T)`). Notifies registered
# listeners on value change (equality-checked) and underpins controlled inputs.

module UI
  # Type-safe reactive state container.
  #
  # When the value changes, all registered listeners are notified with
  # the old and new values. Listeners are NOT called when the same
  # value is assigned (equality check via `!=`).
  #
  # Example:
  #   counter = UI::State(Int32).new(0)
  #   counter.on_change { |old_val, new_val| puts "#{old_val} -> #{new_val}" }
  #   counter.value = 1  # prints "0 -> 1"
  #   counter.value = 1  # no output (same value)
  class State(T)
    # The current value. Read via `state.value`; write via
    # `state.value = ...` (the setter notifies listeners on change).
    getter value : T
    @listeners : Array(Proc(T, T, Nil))

    def initialize(@value : T)
      @listeners = [] of Proc(T, T, Nil)
    end

    # Assigns a new value. If `new_value` is equal to the current value
    # (per `!=`), the setter is a no-op and listeners are NOT called.
    # On change, every registered listener is invoked synchronously with
    # `(old_value, new_value)`. Returns `new_value`.
    def value=(new_value : T) : T
      old = @value
      @value = new_value
      if old != new_value
        @listeners.each { |listener| listener.call(old, new_value) }
      end
      new_value
    end

    # Registers a change listener. The block runs every time
    # `value =` is called with a value not equal to the current one.
    # Listeners run in registration order; raised exceptions abort
    # the remaining listeners on that change (use `begin/rescue`
    # inside the block to swallow if necessary).
    #
    # ```
    # selected = UI::State(Int32).new(0)
    # selected.on_change { |old, new| puts "selection #{old} -> #{new}" }
    # selected.value = 3 # prints "selection 0 -> 3"
    # ```
    def on_change(&block : T, T -> Nil) : Nil
      @listeners << block
    end

    # Removes every registered listener. Use when tearing down a screen
    # whose listeners hold view references that should be GC-eligible.
    def remove_listeners : Nil
      @listeners.clear
    end
  end
end
