# Crystal shared library initialization and cleanup functions.
#
# When Crystal code is compiled with --shared and embedded inside a Swift or
# Kotlin host application, there is no Crystal-generated main() entry point.
# The host application MUST call crystal_init() before invoking any other
# Crystal function, and SHOULD call crystal_cleanup() before unloading the
# library.
#
# Usage (Swift / iOS):
#
#   // In AppDelegate.swift
#   import Foundation
#
#   @_silgen_name("crystal_init")
#   func crystal_init()
#
#   @_silgen_name("crystal_cleanup")
#   func crystal_cleanup()
#
#   class AppDelegate: UIResponder, UIApplicationDelegate {
#     func application(_ application: UIApplication,
#                      didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
#       crystal_init()
#       return true
#     }
#
#     func applicationWillTerminate(_ application: UIApplication) {
#       crystal_cleanup()
#     }
#   }
#
# Usage (Kotlin / Android):
#
#   companion object {
#     init {
#       System.loadLibrary("myapp")
#     }
#   }
#
#   external fun crystalInit()
#   external fun crystalCleanup()
#
# The JNICALL wrapper for Android belongs in your jni_bridge.c:
#
#   // Declare the Crystal functions
#   extern void crystal_init(void);
#   extern void crystal_cleanup(void);
#
#   // Called automatically by Android's linker on System.loadLibrary()
#   JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
#     crystal_init();
#     return JNI_VERSION_1_6;
#   }
#
#   JNIEXPORT void JNICALL
#   Java_com_example_MyApp_crystalInit(JNIEnv *env, jclass cls) {
#     crystal_init();
#   }
#
#   JNIEXPORT void JNICALL
#   Java_com_example_MyApp_crystalCleanup(JNIEnv *env, jclass cls) {
#     crystal_cleanup();
#   }
#
# Note on threading:
#   BoehmGC requires that every thread that allocates Crystal objects is
#   registered with the GC. Call GC.register_thread / GC.unregister_thread
#   (or the C equivalents GC_register_my_thread / GC_unregister_my_thread)
#   for any native thread that calls Crystal functions.
#
# Note on signal handlers (iOS):
#   iOS crash reporting (Crashlytics, etc.) installs its own SIGSEGV/SIGBUS
#   handlers. Crystal's runtime also installs signal handlers. To avoid
#   conflicts, compile with -Dwithout_signal_handlers or restrict Crystal's
#   signal setup to non-iOS platforms via:
#     {% unless flag?(:ios) %}
#       Signal::SEGV.reset
#     {% end %}

# ---------------------------------------------------------------------------
# crystal_init
# ---------------------------------------------------------------------------
# Initialise before other Crystal functions from the application's main thread.
# Android's C wrapper makes subsequent calls idempotent; JNI_OnLoad must check
# crystal_runtime_is_ready before exposing application entrypoints. Apple hosts
# retain their existing single-call startup contract.
#
# Initialises:
#   - BoehmGC (garbage collector)
#   - Crystal standard library internals (thread-local storage, etc.)
#
# Safe to call from C or Swift as:
#   void crystal_init(void);
#
# Safe to call from Kotlin via JNI after declaring:
#   external fun crystalInit()

{% if flag?(:android) %}
  lib LibAndroidRuntimeLog
    fun crystal_android_log_runtime_error(message : UInt8*)
  end

  # C owns the once gate: Crystal synchronization is not available before
  # this function initializes the runtime. build_android.sh links the wrapper.
  fun crystal_android_initialize_runtime(argc : Int32, argv : UInt8**) : Int32
    GC.init
    Crystal.init_runtime
    # __crystal_main initializes eager constants/class variables, the default
    # execution context (kernel.cr), and application top-level declarations.
    # Calling just init_runtime leaves those globals zeroed. Do not call
    # Crystal.main/exit: the Android host owns process lifetime and cleanup.
    Crystal.main_user_code(argc, argv)
    0
rescue ex
  message = String.build { |io| ex.inspect_with_backtrace(io) }
  LibAndroidRuntimeLog.crystal_android_log_runtime_error(message.to_unsafe)
  -1
  end
{% else %}
  fun crystal_init : Nil
    GC.init
    Crystal.init_runtime
  end
{% end %}

# ---------------------------------------------------------------------------
# crystal_cleanup
# ---------------------------------------------------------------------------
# Perform a final GC collection and release Crystal runtime resources.
#
# Call this when the host application is about to unload the shared library
# or before the process exits. It is safe to skip in practice (the OS will
# reclaim memory), but calling it ensures Crystal finalizers run and helps
# with leak detection tools.
#
# Safe to call from C or Swift as:
#   void crystal_cleanup(void);

fun crystal_cleanup : Nil
  # Run a final collection to execute pending finalizers (e.g. File#close,
  # NativeHandle#finalize, etc.).
  GC.collect

  nil
end

# Native-thread registration cannot safely be implemented as a Crystal
# function: entering that wrapper would already execute Crystal on an
# unregistered stack. Android builds therefore link `crystal_gc_threads.c`.
# JNI entrypoints call its C helpers before dispatching into Crystal and call
# the matching unregister helper only when this bridge registered the thread.
