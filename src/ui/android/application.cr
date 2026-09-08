{% unless flag?(:android) %}
  {% raise "asset_pipeline/ui/android/application is an Android entrypoint; compile with an Android target triple." %}
{% end %}

require "../../../scripts/crystal_init"
require "../../ui"
require "./services"
require "./navigation_state"
require "./viewport"
require "./fonts"
require "./photos"

lib LibAndroidApplicationLog
  fun android_host_log_crystal_error(message : UInt8*)
  fun android_host_request_render : Int32
  fun android_host_bundled_assets_dir(buffer : UInt8*, capacity : Int32) : Int32
  fun android_host_app_directory(kind : Int32, buffer : UInt8*, capacity : Int32) : Int32
  fun android_host_setting(key : UInt8*, key_size : Int32, buffer : UInt8*, capacity : Int32) : Int32
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
  @@viewport : Viewport? = nil
  @@viewport_handler : Proc(Viewport, Nil)? = nil
  @@bundled_assets_dir : String? = nil
  @@bundled_assets_read = false
  @@files_dir : String? = nil
  @@cache_dir : String? = nil

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

  # The host's viewport: the rectangle the tree is laid out in and the
  # system-bar insets left for the application, in dp. Reported before every
  # render and on every change; nil until the first report.
  def self.viewport : Viewport?
    @@viewport
  end

  # Sees every viewport change, on the main looper, before the render that
  # follows it. The host never re-renders for a viewport change by itself: a
  # handler that re-lays out calls `invalidate` when a tree is already
  # mounted (`mounted?`); before the first render the values are simply in
  # place for it.
  def self.on_viewport(&handler : Viewport -> Nil) : Nil
    raise ArgumentError.new("Android viewport handler is already configured") if @@viewport_handler
    @@viewport_handler = handler
  end

  # True when the report differs from the last one and the handler ran.
  def self.report_viewport(viewport : Viewport) : Bool
    return false if @@viewport == viewport
    @@viewport = viewport
    @@viewport_handler.try(&.call(viewport))
    true
  end

  # A native tree is mounted for this process.
  def self.mounted? : Bool
    !@@last_native.nil?
  end

  # The directory the host extracted the APK's bundle into (art, fonts and
  # documents as real files), or nil when the APK carries none. Fixed for
  # the life of the process, so it is read from the host once.
  def self.bundled_assets_dir : String?
    return @@bundled_assets_dir if @@bundled_assets_read
    buffer = Bytes.new(4096)
    length = LibAndroidApplicationLog.android_host_bundled_assets_dir(buffer.to_unsafe, buffer.size)
    raise "Android bundled assets directory unavailable" if length < 0
    @@bundled_assets_read = true
    @@bundled_assets_dir = length == 0 ? nil : String.new(buffer[0, length])
  end

  # The application's private files directory (durable) and cache directory
  # (purgeable by the system), canonical, as the host hands them over. An
  # application puts its caches, cookie jars and documents under them instead
  # of guessing a home directory, which Android does not set.
  def self.files_dir : String
    @@files_dir ||= host_directory(1)
  end

  def self.cache_dir : String
    @@cache_dir ||= host_directory(2)
  end

  private def self.host_directory(kind : Int32) : String
    buffer = Bytes.new(4096)
    length = LibAndroidApplicationLog.android_host_app_directory(kind, buffer.to_unsafe, buffer.size)
    raise "Android private directory unavailable" if length <= 0
    String.new(buffer[0, length])
  end

  # A setting the host application baked into its build and registered with
  # the runtime before the first render (`HostSettings`), or nil when the
  # build carries none under that key: the Android side of the keys an iOS
  # host reads from Info.plist. Keys are 1..64 bytes of `[A-Za-z0-9_.]`,
  # values up to 4096 UTF-8 bytes. Contract: `docs/android-settings.md`.
  def self.setting(key : String) : String?
    unless (1..64).includes?(key.bytesize) && key.each_char.all? { |c| c.ascii_alphanumeric? || c == '_' || c == '.' }
      raise ArgumentError.new("Android host setting keys are 1..64 characters of letters, digits, _ and .")
    end
    buffer = Bytes.new(4096)
    length = LibAndroidApplicationLog.android_host_setting(key.to_unsafe, key.bytesize, buffer.to_unsafe, buffer.size)
    raise "Android host setting unavailable" if length < 0
    length == 0 ? nil : String.new(buffer[0, length])
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

# 1 means the viewport changed, 0 means it matched the last report, -1 is a
# contained Crystal failure the host treats as terminal.
fun crystal_android_host_viewport(width : Float64, height : Float64, top : Float64, bottom : Float64,
                                  left : Float64, right : Float64, density : Float64) : Int32
  viewport = UI::Android::Viewport.new(width, height, top, bottom, left, right, density)
  UI::Android::Application.report_viewport(viewport) ? 1 : 0
  rescue error
    UI::Android::Application.log_exception(error)
    -1
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
