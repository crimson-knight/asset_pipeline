require "./release_strategy"
require "./lib_objc_runtime"

module UI
  # Wraps a raw `Void*` pointer to a platform-native object with explicit
  # ownership semantics determined by a `ReleaseStrategy`.
  #
  # ## Deterministic Cleanup vs GC Safety Net
  #
  # The preferred cleanup path is `release!`, which immediately frees the
  # native resource and poisons the pointer to catch use-after-free bugs.
  # The `finalize` method acts as a GC safety net for handles that were
  # not explicitly released -- it should NOT be relied upon as the primary
  # cleanup mechanism.
  #
  # ## Thread Safety
  #
  # `NativeHandle` instances are NOT thread-safe. A handle should be owned
  # by a single `NativeView` and released on the same thread that created it.
  #
  # ## Usage
  #
  # ```
  # handle = UI::NativeHandle.new(some_ptr, UI::ReleaseStrategy::ObjCRelease, label: "NSButton")
  # handle.valid?  # => true
  # handle.ptr!    # => some_ptr (raises if released or null)
  # handle.release!
  # handle.valid?  # => false
  # handle.release! # safe: idempotent, no-op on second call
  # ```
  class NativeHandle
    # The raw pointer to the platform-native object.
    # After `release!`, this is poisoned to `Pointer(Void).null`.
    getter ptr : Void*

    # The ownership strategy that determines how the pointer is released.
    getter strategy : ReleaseStrategy

    # Whether `release!` has been called. Once true, the handle is dead.
    getter? released : Bool = false

    # Optional debug label identifying what this handle wraps.
    # Only used for diagnostics and leak tracking.
    getter label : String?

    def initialize(@ptr : Void*, @strategy : ReleaseStrategy, @label : String? = nil)
      {% if flag?(:ui_debug) %}
        UI::NativeHandleTracker.register(self)
      {% end %}
    end

    # Deterministic cleanup. Releases the native resource according to the
    # strategy and poisons the pointer.
    #
    # This method is idempotent: calling it multiple times is safe and has
    # no effect after the first call.
    def release! : Nil
      return if @released
      @released = true
      perform_release unless @ptr.null?
      @ptr = Pointer(Void).null

      {% if flag?(:ui_debug) %}
        UI::NativeHandleTracker.unregister(self)
      {% end %}
    end

    # Returns the raw pointer, raising if the handle has been released
    # or the pointer is null.
    #
    # Use this when you need a guaranteed-valid pointer for FFI calls.
    #
    # Raises `Exception` if the handle is released or wraps a null pointer.
    def ptr! : Void*
      if @released
        raise "NativeHandle(#{@label || "unlabeled"}) has been released"
      end
      if @ptr.null?
        raise "NativeHandle(#{@label || "unlabeled"}) wraps a null pointer"
      end
      @ptr
    end

    # Returns `true` if the handle wraps a non-null pointer and has not
    # been released.
    def valid? : Bool
      !@released && !@ptr.null?
    end

    # GC safety net. If the handle was never explicitly released, attempt
    # to clean up the native resource. This is a last resort -- always
    # prefer calling `release!` or `NativeView#teardown!` explicitly.
    def finalize
      return if @released
      @released = true
      perform_release unless @ptr.null?
      @ptr = Pointer(Void).null
    end

    # Performs the platform-specific release of the native pointer.
    # Gated with compile-time flags so no platform code leaks into
    # other targets.
    private def perform_release : Nil
      case @strategy
      when .obj_c_release?
        {% if flag?(:darwin) %}
          LibObjCRuntime.objc_release(@ptr)
        {% end %}
      when .jni_global_ref?
        {% if flag?(:android) %}
          # JNI global refs require a JNIEnv* to delete. The JNIEnv is
          # stored on the NativeView that owns this handle. At finalize
          # time we cannot safely obtain a JNIEnv, so JNI handles MUST
          # be released explicitly via release! before GC collection.
          # This is a known limitation -- the handle tracker will flag
          # unreleased JNI handles as leaks.
        {% end %}
      when .obj_c_borrowed?, .unowned?
        # No-op: borrowed and unowned pointers are not our responsibility.
      end
    end
  end
end
