# Cases that suspend or block the main fiber in the ways an AppKit app does,
# and check after every wait that it still runs on the main thread. Each case
# runs its helper fibers in its own `Fiber::ExecutionContext::Parallel`, so the
# default context (parallelism 1, the main thread) only runs the main fiber.
module ProbeCases
  record CaseResult, name : String, is_data_complete : Bool, count_of_off_main_observations : Int32, detail : String do
    def passed? : Bool
      is_data_complete && count_of_off_main_observations == 0
    end

    def summary : String
      "case=#{name} ok=#{passed?} off_main_observations=#{count_of_off_main_observations} #{detail}"
    end
  end

  def self.on_main_thread? : Bool
    LibProbe.pthread_main_np == 1
  end

  # The main fiber waits on a pipe that a Parallel fiber feeds in timed chunks
  # (an event-loop wait), reads a 4 MB regular file several times (blocking
  # read syscalls), and sleeps (a timer wait).
  class WaitOnBlockingIoFromMainFiber
    COUNT_OF_PIPE_CHUNKS =    20
    PIPE_CHUNK_SIZE      = 4_096
    FILE_SIZE            = 4 * 1_024 * 1_024
    COUNT_OF_FILE_READS  = 10
    COUNT_OF_SLEEPS      =  5

    @count_of_off_main_observations = 0

    def perform : CaseResult
      pipe_bytes = read_pipe_fed_by_worker
      file_bytes = read_file_repeatedly
      sleep_on_main_fiber
      is_data_complete = pipe_bytes == COUNT_OF_PIPE_CHUNKS * PIPE_CHUNK_SIZE &&
                         file_bytes == COUNT_OF_FILE_READS * FILE_SIZE
      CaseResult.new("blocking-io", is_data_complete, @count_of_off_main_observations,
        "pipe_bytes=#{pipe_bytes} file_bytes=#{file_bytes}")
    end

    private def observe_main_thread : Nil
      @count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?
    end

    private def read_pipe_fed_by_worker : Int32
      reader, writer = IO.pipe
      feeder = Fiber::ExecutionContext::Parallel.new("probe-io-feeder", 1)
      feeder.spawn do
        chunk = Bytes.new(PIPE_CHUNK_SIZE, 0x61_u8)
        COUNT_OF_PIPE_CHUNKS.times do
          sleep 5.milliseconds
          writer.write(chunk)
        end
      ensure
        writer.close
      end

      buffer = Bytes.new(PIPE_CHUNK_SIZE)
      total = 0
      while (count = reader.read(buffer)) > 0
        total += count
        observe_main_thread
      end
      reader.close
      total
    end

    private def read_file_repeatedly : Int32
      path = File.tempname("main-thread-probe", ".bin")
      File.write(path, Bytes.new(FILE_SIZE, 0x62_u8))
      total = 0
      COUNT_OF_FILE_READS.times do
        total += File.read(path).bytesize
        observe_main_thread
      end
      total
    ensure
      File.delete(path) if path && File.exists?(path)
    end

    private def sleep_on_main_fiber : Nil
      COUNT_OF_SLEEPS.times do
        sleep 10.milliseconds
        observe_main_thread
      end
    end
  end

  # The main fiber and four Parallel fibers increment one counter under one
  # `Mutex`; the workers hold it across `File.open`, so the main fiber suspends
  # on the lock and is woken from another thread.
  class ContendForMutexFromMainFiber
    COUNT_OF_WORKERS           =     4
    WORKER_ITERATIONS          = 2_000
    MAIN_FIBER_ITERATIONS      =   500
    WORKER_FILE_OPEN_FREQUENCY =    10

    @count_of_off_main_observations = 0

    def perform : CaseResult
      lock = Mutex.new
      counter = 0
      wait_group = WaitGroup.new(COUNT_OF_WORKERS)
      workers = Fiber::ExecutionContext::Parallel.new("probe-mutex-workers", COUNT_OF_WORKERS)
      COUNT_OF_WORKERS.times do
        workers.spawn do
          WORKER_ITERATIONS.times do |step|
            lock.synchronize do
              counter += 1
              File.open(__FILE__) { } if step % WORKER_FILE_OPEN_FREQUENCY == 0
            end
          end
        ensure
          wait_group.done
        end
      end

      MAIN_FIBER_ITERATIONS.times do
        lock.synchronize do
          counter += 1
          @count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?
        end
      end
      wait_group.wait
      @count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?

      expected = COUNT_OF_WORKERS * WORKER_ITERATIONS + MAIN_FIBER_ITERATIONS
      CaseResult.new("mutex", counter == expected, @count_of_off_main_observations,
        "counter=#{counter} expected=#{expected}")
    end
  end

  # Native code calls a Crystal callback synchronously (like a target-action or
  # delegate method) and through the main dispatch queue while the main run
  # loop runs (like a completion posted from a worker). Each callback opens
  # files and takes a `Mutex` that a Parallel fiber keeps contending.
  class CallBackIntoCrystalFromNativeCode
    COUNT_OF_SYNCHRONOUS_CALLBACKS =   20
    COUNT_OF_MAIN_QUEUE_CALLBACKS  =   50
    MAIN_QUEUE_TIMEOUT_SECONDS     = 10.0
    FILE_OPENS_PER_CALLBACK        =    5

    @@lock = Mutex.new
    @@count_of_callbacks = 0
    @@count_of_off_main_observations = 0

    def self.handle_callback(index : Int32) : Nil
      @@count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?
      FILE_OPENS_PER_CALLBACK.times { File.open(__FILE__) { } }
      @@lock.synchronize { @@count_of_callbacks += 1 }
      @@count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?
    end

    def perform : CaseResult
      is_contending = Atomic(Bool).new(true)
      contender_done = WaitGroup.new(1)
      contender = Fiber::ExecutionContext::Parallel.new("probe-callback-contender", 1)
      contender.spawn do
        while is_contending.get
          @@lock.synchronize { sleep 1.millisecond }
        end
      ensure
        contender_done.done
      end

      callback = ->(index : LibC::Int) { CallBackIntoCrystalFromNativeCode.handle_callback(index.to_i32) }
      synchronous_runs = LibProbe.probe_call_back_synchronously(callback, COUNT_OF_SYNCHRONOUS_CALLBACKS)
      main_queue_runs = LibProbe.probe_call_back_on_main_queue(callback, COUNT_OF_MAIN_QUEUE_CALLBACKS, MAIN_QUEUE_TIMEOUT_SECONDS)

      is_contending.set(false)
      contender_done.wait
      @@count_of_off_main_observations += 1 unless ProbeCases.on_main_thread?

      expected = COUNT_OF_SYNCHRONOUS_CALLBACKS + COUNT_OF_MAIN_QUEUE_CALLBACKS
      is_data_complete = synchronous_runs == COUNT_OF_SYNCHRONOUS_CALLBACKS &&
                         main_queue_runs == COUNT_OF_MAIN_QUEUE_CALLBACKS &&
                         @@count_of_callbacks == expected
      CaseResult.new("native-callback", is_data_complete, @@count_of_off_main_observations,
        "synchronous=#{synchronous_runs} main_queue=#{main_queue_runs} callbacks=#{@@count_of_callbacks} expected=#{expected}")
    end
  end
end
