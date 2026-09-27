# Force-triggers the main-fiber migration: blocks the main fiber in
# `Fiber.syscall` (File.open) for more than 100 ms, then initializes an
# offscreen NSWindow. Built with the default execution-context runtime (never
# -Dwithout_mt).
#
#   -Dwith_main_thread_fix  requires UI::MainThread (src/ui/native/main_thread.cr)
#   --workers               also runs CPU and File.open work in a Parallel
#                           context and checks it used threads other than main
#
# Exit 0: the window initialized on the main thread. Without the fix the
# expected failure is SIGTRAP (exit 133) from the NSWindow initializer.

{% if flag?(:with_main_thread_fix) %}
  require "../../src/ui/native/main_thread"
{% end %}
require "wait_group"

@[Link(framework: "AppKit")]
lib LibProbe
  fun probe_make_offscreen_window : LibC::Int
  fun pthread_main_np : LibC::Int
end

SYSCALL_WINDOW         = 150.milliseconds
SYSCALL_DEADLINE       = 2.seconds
COUNT_OF_WORKER_FIBERS =      8
WORKER_ITERATIONS      = 20_000

# Opens files for at least SYSCALL_WINDOW, and keeps going (up to
# SYSCALL_DEADLINE) until the main fiber has left the main thread, so the
# unfixed build migrates on every run instead of only when a monitor tick
# happens to land inside one of the first opens.
def block_main_fiber_in_syscalls : Int32
  start = Time.instant
  count_of_opens = 0
  loop do
    File.open(__FILE__) { }
    count_of_opens += 1
    elapsed = Time.instant - start
    break if elapsed >= SYSCALL_DEADLINE
    break if elapsed >= SYSCALL_WINDOW && LibProbe.pthread_main_np != 1
  end
  count_of_opens
end

def start_workers(results : Array(Int64), thread_names : Set(String), lock : Mutex, wait_group : WaitGroup) : Nil
  workers = Fiber::ExecutionContext::Parallel.new("probe-workers", 4)
  COUNT_OF_WORKER_FIBERS.times do |index|
    workers.spawn do
      sum = 0_i64
      WORKER_ITERATIONS.times do |step|
        sum &+= step.to_i64 * (index + 1)
        File.open(__FILE__) { } if step % 1_000 == 0
      end
      on_main = LibProbe.pthread_main_np == 1
      lock.synchronize do
        results << sum
        thread_names << "#{Thread.current.name}#{on_main ? "(main)" : ""}"
      end
    ensure
      wait_group.done
    end
  end
end

use_workers = ARGV.includes?("--workers")
results = [] of Int64
thread_names = Set(String).new
lock = Mutex.new
wait_group = WaitGroup.new(use_workers ? COUNT_OF_WORKER_FIBERS : 0)
start_workers(results, thread_names, lock, wait_group) if use_workers

LibProbe.probe_make_offscreen_window
count_of_opens = block_main_fiber_in_syscalls
on_main_after_syscalls = LibProbe.pthread_main_np == 1
STDOUT.puts "opens=#{count_of_opens} main_thread_after_syscalls=#{on_main_after_syscalls} thread=#{Thread.current.name}"
STDOUT.flush

{% if flag?(:with_main_thread_fix) %}
  UI::MainThread.assert!("probe NSWindow init")
{% end %}
LibProbe.probe_make_offscreen_window

if use_workers
  wait_group.wait
  expected = (0...COUNT_OF_WORKER_FIBERS).map { |index| (0_i64...WORKER_ITERATIONS.to_i64).sum * (index + 1) }
  worker_sums_match = results.sort == expected.sort
  off_main = thread_names.count { |name| !name.ends_with?("(main)") }
  STDOUT.puts "workers_ok=#{worker_sums_match} worker_threads=#{thread_names.to_a.sort.join(",")} off_main_threads=#{off_main}"
  exit 3 unless worker_sums_match && off_main > 0
end

exit(LibProbe.pthread_main_np == 1 ? 0 : 2)
