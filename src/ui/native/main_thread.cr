# Keeps the main fiber on the main thread for AppKit apps, and fails loudly
# when an AppKit entry point runs anywhere else.
#
# AppKit must only be used from the process's main thread. Crystal 1.21 runs
# execution contexts by default: the main fiber lives in the default
# `Fiber::ExecutionContext::Parallel` context, whose first scheduler is bound
# to the main thread. Every 10 ms the runtime's monitor thread looks for a
# scheduler whose thread is inside `Fiber.syscall` (`File.open`,
# `getaddrinfo`) and hands that scheduler to a pool thread. When the scheduler
# is the main thread's, the main fiber resumes on the pool thread
# (`DEFAULT-0`), the main thread parks in the thread pool, and the next
# `NSWindow` initializer raises `NSInternalInconsistencyException`. That
# exception cannot unwind through Crystal frames, so the process dies with
# SIGTRAP (exit 133).
#
# The fix below makes `Fiber.syscall` skip the handoff bookkeeping while it runs
# on the main thread, so the monitor never sees the main thread's scheduler as
# detachable. Every other thread keeps the stock behavior, and the default
# multithreaded runtime stays on. See `UI::MainThread` for the cost.

{% if flag?(:macos) || flag?(:ios) %}
  module UI::MainThread
    lib LibPthreadMainThread
      # Returns 1 on the process's main thread, 0 elsewhere (libSystem).
      fun pthread_main_np : LibC::Int
    end

    # Raised when an AppKit entry point runs off the main thread. Raising here,
    # before any AppKit call, replaces the SIGTRAP AppKit would otherwise cause.
    class OffMainThreadError < Exception
      def initialize(entry_point : String)
        super(
          "#{entry_point} called off the main thread (thread #{Thread.current.name.inspect}). " \
          "AppKit must run on the main thread. The main fiber moved to another thread, or this " \
          "code runs in a fiber that is not the main fiber. See src/ui/native/main_thread.cr."
        )
      end
    end

    # Whether the current thread is the process's main thread.
    def self.on_main_thread? : Bool
      LibPthreadMainThread.pthread_main_np == 1
    end

    # Raises `OffMainThreadError` naming *entry_point* unless the current thread
    # is the main thread.
    def self.assert!(entry_point : String) : Nil
      raise OffMainThreadError.new(entry_point) unless on_main_thread?
    end

    # Whether this build keeps the main thread's scheduler out of the monitor's
    # syscall handoff. False on iOS (not patched yet), when execution contexts
    # are off (`-Dwithout_mt`),
    # where the main fiber cannot leave the main thread anyway, and when the
    # stdlib no longer has the `Fiber.syscall` seam the fix reopens.
    def self.pins_main_fiber? : Bool
      {% if flag?(:macos) && (!flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context)) &&
              Fiber.class.has_method?(:syscall) %}
        true
      {% else %}
        false
      {% end %}
    end
  end

  {% if flag?(:macos) && (!flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context)) &&
          Fiber.class.has_method?(:syscall) %}
    class Fiber
      # Runs a syscall on the main thread without marking its scheduler as
      # detachable, so the monitor never moves the main fiber off the main
      # thread. Off the main thread this is the stock `Fiber.syscall`.
      #
      # Cost: while the main thread blocks in the syscall, the other fibers of
      # the default context wait for it instead of moving to a pool thread.
      # The default context has a parallelism of one, so those fibers share the
      # main thread already; a blocking syscall on the main thread also stalls
      # the AppKit run loop regardless of this patch. Work that must keep
      # running belongs in its own `Fiber::ExecutionContext::Parallel`.
      def self.syscall(&)
        if UI::MainThread.on_main_thread?
          yield
        else
          previous_def { yield }
        end
      end
    end
  {% end %}
{% end %}
