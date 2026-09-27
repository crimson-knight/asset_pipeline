require "spec"
require "../../src/ui/native/main_thread"

# AppKit must only be used from the main thread. Every native macOS spec runs
# AppKit calls on the main fiber, so the main fiber has to stay on the main
# thread for the whole run.
#
# Under the execution-context runtime (the default since Crystal 1.21), the
# monitor thread moves a scheduler to another thread whenever its 10 ms tick
# lands while that scheduler is inside `Fiber.syscall` (`File.open`,
# `getaddrinfo`, ...). Without `UI::MainThread` the main fiber then resumes on
# a pool thread and the next AppKit call traps. `src/ui/native/main_thread.cr`
# keeps the main thread's scheduler out of that handoff; these specs prove it
# with the default multithreaded runtime.
{% if flag?(:macos) %}
  # Opening a file enters `Fiber.syscall`; without the fix, 300 ms of opens
  # moves the main fiber off the main thread on most runs.
  SYSCALL_WINDOW_FOR_MAIN_THREAD_AFFINITY = 300.milliseconds

  describe UI::MainThread do
    it "pins the main fiber when execution contexts are on" do
      {% if !flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context) %}
        UI::MainThread.pins_main_fiber?.should be_true
      {% else %}
        UI::MainThread.pins_main_fiber?.should be_false
      {% end %}
    end

    it "keeps the main fiber on the main thread across blocking syscalls" do
      UI::MainThread.on_main_thread?.should be_true

      deadline = Time.instant + SYSCALL_WINDOW_FOR_MAIN_THREAD_AFFINITY
      count_of_opens = 0
      while Time.instant < deadline
        File.open(__FILE__) { }
        count_of_opens += 1
        break unless UI::MainThread.on_main_thread?
      end

      count_of_opens.should be > 0
      UI::MainThread.on_main_thread?.should be_true
    end

    it "keeps other threads' syscalls moving while the main fiber stays put" do
      {% if !flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context) %}
        workers = Fiber::ExecutionContext::Parallel.new("main-thread-spec-workers", 2)
        list_of_worker_results = Channel(Bool).new(4)
        4.times do
          workers.spawn do
            200.times { File.open(__FILE__) { } }
            list_of_worker_results.send(UI::MainThread.on_main_thread?)
          end
        end
        200.times { File.open(__FILE__) { } }

        list_of_worker_results_seen = Array.new(4) { list_of_worker_results.receive }
        list_of_worker_results_seen.none?.should be_true
        UI::MainThread.on_main_thread?.should be_true
      {% end %}
    end

    it "is quiet on the main thread" do
      UI::MainThread.assert!("spec entry point")
    end

    it "raises a named error off the main thread" do
      {% if !flag?(:without_mt) && !flag?(:preview_mt) || flag?(:execution_context) %}
        message = Channel(String?).new(1)
        isolated = Fiber::ExecutionContext::Isolated.new("main-thread-spec-off-main") do
          UI::MainThread.assert!("spec entry point")
          message.send(nil)
        rescue error : UI::MainThread::OffMainThreadError
          message.send(error.message)
        end
        received = message.receive
        isolated.wait

        received.should_not be_nil
        received.to_s.should contain("spec entry point called off the main thread")
      {% end %}
    end
  end
{% end %}
