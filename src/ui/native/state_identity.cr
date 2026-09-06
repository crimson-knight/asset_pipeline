require "mutex"
require "atomic"

module UI::NativeStateIdentity
  @@mutex = Mutex.new
  @@next = 0_u64

  # Process-local monotonic identity. Heap addresses may be reused after GC;
  # a saved navigation scope must never identify an unrelated newer screen.
  def self.allocate : UInt64
    @@mutex.synchronize do
      raise "Native state identity space exhausted" if @@next == UInt64::MAX
      @@next += 1_u64
    end
  end
end
