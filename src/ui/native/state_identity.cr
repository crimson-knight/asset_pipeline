require "atomic"

module UI::NativeStateIdentity
  @@next = Atomic(UInt64).new(0_u64)

  # Process-local monotonic identity. Heap addresses may be reused after GC;
  # a saved navigation scope must never identify an unrelated newer screen.
  #
  # Lock-free on purpose: identities are also requested from threads the
  # Crystal scheduler does not own (JVM threads on Android, raw `Thread`s in
  # specs). A fiber-aware Mutex that has to wake a waiter on such a thread
  # fails with "Fiber#execution_context cannot be nil" on Crystal 1.21.
  def self.allocate : UInt64
    previous = @@next.add(1_u64)
    raise "Native state identity space exhausted" if previous == UInt64::MAX
    previous &+ 1_u64
  end
end
