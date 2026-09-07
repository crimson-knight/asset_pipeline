{% unless flag?(:android) %}
  {% raise "asset_pipeline/ui/android/application is an Android entrypoint; compile with an Android target triple." %}
{% end %}

require "../../../scripts/crystal_init"
require "../../ui"
require "./services"
require "./navigation_state"

lib LibAndroidApplicationLog
  fun android_host_log_crystal_error(message : UInt8*)
  fun android_host_request_render : Int32
end

module UI::Android::Application
  # Host visibility is deliberately independent of View tree ownership.
  # Stop is an explicit terminal close, not Activity.onDestroy/process death.
  enum LifecycleEvent
    Foreground = 1
    Background = 2
    Stop       = 3
  end

  @@factory : Proc(String, UI::View)? = nil
  @@lifecycle_handler : Proc(LifecycleEvent, Nil)? = nil
  @@last_native : UI::NativeView? = nil
  @@navigation : UI::Android::NavigationState? = nil
  @@probe_base = 40
  @@tick_handler : Proc(Nil)? = nil
  @@tick_interval_ms = 0

  # Configure at application startup. Hosts mount, mutate and tear down views
  # on the Android main looper. One retained tree is supported per process.
  def self.configure(&factory : String -> UI::View) : Nil
    raise ArgumentError.new("Android application is already configured") if @@factory
    @@factory = factory
  end

  def self.on_lifecycle(&handler : LifecycleEvent -> Nil) : Nil
    raise ArgumentError.new("Android lifecycle handler is already configured") if @@lifecycle_handler
    @@lifecycle_handler = handler
  end

def self.lifecycle(event : LifecycleEvent) : Nil
  @@lifecycle_handler.try(&.call(event))
end

# A host-driven periodic callback on the Android main looper while the
# surface is in the foreground. The host runs the first tick right after
# the first render, then every `interval_ms`, never overlapping, and stops
# on background, detach and failure. The handler does one bounded unit of
# work and calls `invalidate` only when a re-render is owed; the host never
# re-renders on a tick by itself, so a focused editor is not replaced by a
# clock. Raising inside the handler is a contained boundary failure: the
# session becomes terminal, the same as a failed callback.
def self.on_tick(interval_ms : Int32, &handler : -> Nil) : Nil
  raise ArgumentError.new("Android tick interval must be positive") unless interval_ms > 0
  raise ArgumentError.new("Android tick handler is already configured") if @@tick_handler
  @@tick_interval_ms = interval_ms
  @@tick_handler = handler
end

# 0 means the application asked for no ticks and the host schedules none.
def self.tick_interval_ms : Int32
  @@tick_handler ? @@tick_interval_ms : 0
end

def self.tick : Nil
  @@tick_handler.try(&.call)
end

  # Request a deferred host refresh after an asynchronous state change. Ordinary
  # service completions do not inherently replace a focused native editor.
  def self.invalidate : Nil
    raise "Android render invalidation unavailable" if LibAndroidApplicationLog.android_host_request_render == 0
  end

  def self.render(env : Void*, context : Void*, route : String = "main") : Void*
    factory = @@factory || raise "Configure UI::Android::Application before rendering"
    release_native_tree
    renderer = UI::Android::Renderer.new(env, context)
    native = renderer.render(factory.call(route))
    @@last_native = native
    @@navigation = renderer.navigation
    native.handle.ptr!
  end

  def self.teardown : Nil
    UI::Android::Sheets.discard_retirement
    release_native_tree
  end

  private def self.release_native_tree : Nil
    @@navigation = nil
    if previous = @@last_native
      @@last_native = nil
      previous.teardown!
    end
  end

  def self.can_go_back? : Bool
    @@navigation.try(&.can_go_back?) || false
  end

  def self.go_back : Bool
    @@navigation.try(&.go_back) || false
  end

  # Exercises eager global initialization and the default fiber scheduler, not
  # merely a constant return from a JNI-compatible function.
  def self.runtime_probe : Int32
    channel = Channel(Int32).new
    spawn { channel.send(@@probe_base + 2) }
    channel.receive
  end

  def self.log_exception(error : Exception) : Nil
    # Exceptions may contain user text, URLs, secrets or filesystem paths.
    # Runtime diagnostics report the type only; do not format an application
    # message/backtrace while already handling a native boundary failure.
    message = error.class.to_s
    LibAndroidApplicationLog.android_host_log_crystal_error(message.to_unsafe)
  rescue
    LibAndroidApplicationLog.android_host_log_crystal_error("Exception diagnostics unavailable")
  end
end

# -1 means a contained Crystal failure, 0 means root/no action, 1 means handled.
fun crystal_android_host_navigation_back(commit : Int32) : Int32
  (commit == 0 ? UI::Android::Application.can_go_back? : UI::Android::Application.go_back) ? 1 : 0
  rescue error
    UI::Android::Application.log_exception(error)
    -1
end

# Never unwind a Crystal exception through JNI. Kotlin treats a failed event
# as a terminal session failure and refuses subsequent activation.
fun crystal_android_host_lifecycle(event : Int32) : Int32
  UI::Android::Application.lifecycle(UI::Android::Application::LifecycleEvent.from_value(event))
  1
  rescue error
    UI::Android::Application.log_exception(error)
    0
end

fun crystal_android_host_tick_interval : Int32
  UI::Android::Application.tick_interval_ms
  rescue error
    UI::Android::Application.log_exception(error)
    0
end

# 1 means the tick ran; 0 is a contained Crystal failure the host treats
# as terminal, the same as a failed callback.
fun crystal_android_host_tick : Int32
  UI::Android::Application.tick
  1
  rescue error
    UI::Android::Application.log_exception(error)
    0
end

# -1 contains application failure; 1 means a structural dismissal completed.
# Lifecycle/recreation discards this handoff instead of firing on_dismiss.
fun crystal_android_host_sheet_transition(dismissed : Int32) : Int32
  raise ArgumentError.new("Invalid Android sheet transition") unless dismissed == 0 || dismissed == 1
  UI::Android::Sheets.finish_retirement(dismissed == 1) ? 1 : 0
  rescue error
    UI::Android::Application.log_exception(error)
    -1
end

fun crystal_android_runtime_probe : Int32
  UI::Android::Application.runtime_probe
  rescue error
    UI::Android::Application.log_exception(error)
    -1
end

fun crystal_android_host_teardown : Nil
  UI::Android::Application.teardown
  rescue error
    UI::Android::Application.log_exception(error)
end

fun crystal_android_host_callback_count : Int32
  UI::CallbackRegistry.size
end

fun crystal_android_host_render_slug(env : Void*, context : Void*, route_ptr : UInt8*) : Void*
  route = route_ptr.null? ? "main" : String.new(route_ptr)
  UI::Android::Application.render(env, context, route)
  rescue error
    UI::Android::Application.log_exception(error)
    Pointer(Void).null
end

# New hosts preserve NUL and supplementary Unicode characters in route names.
# The legacy export above remains available to existing C-string consumers.
fun crystal_android_host_render_slug_bytes(env : Void*, context : Void*, route_ptr : UInt8*, byte_len : Int32) : Void*
  raise ArgumentError.new("Invalid native route length") if byte_len < 0
  route = route_ptr.null? ? "main" : String.new(route_ptr, byte_len)
  UI::Android::Application.render(env, context, route)
  rescue error
    UI::Android::Application.log_exception(error)
    Pointer(Void).null
end
