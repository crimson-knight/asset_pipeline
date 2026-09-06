lib LibAndroidServices
  fun android_host_storage_submit(id : UInt64, operation : Int32, key : UInt8*, key_size : Int32, value : UInt8*, value_size : Int32) : Int32
  fun android_host_service_cancel(id : UInt64) : Int32
  fun android_host_http_submit(id : UInt64, packet : UInt8*, size : Int32) : Int32
  fun android_host_notifications_submit(id : UInt64, packet : UInt8*, size : Int32) : Int32
  fun android_host_secrets_submit(id : UInt64, operation : Int32, key : UInt8*, key_size : Int32, value : UInt8*, value_size : Int32) : Int32
  fun android_host_files_submit(id : UInt64, operation : Int32, path : UInt8*, path_size : Int32, data : UInt8*, data_size : Int32) : Int32
end

module UI::Android::Services
  class Unavailable < Exception
  end

  enum Status
    OK               = 0
    NotFound         = 1
    Unavailable      = 2
    PermissionDenied = 3
    Cancelled        = 4
    InvalidInput     = 5
    IO               = 6
    Network          = 7
  end

  record Reply, status : Status, data : Bytes

  class Operation
    getter id : UInt64
    getter? completed = false

    def initialize(@id : UInt64)
    end

    def cancel : Nil
      return if @completed
      raise Unavailable.new("Android cancellation transport unavailable") if LibAndroidServices.android_host_service_cancel(@id) == 0
    end

    def finish : Nil
      @completed = true
    end
  end

  record Pending, operation : Operation, completion : Proc(Reply, Nil)
  @@pending = {} of UInt64 => Pending
  @@next_id = 0_u64

  def self.storage(operation : Int32, key : String, value : String = "", &completion : Reply -> Nil) : Operation
    raise ArgumentError.new("Storage key/value exceeds the transport limit") if key.bytesize > 512 || value.bytesize > 1_048_576
    token = register(completion)
    accept(token, LibAndroidServices.android_host_storage_submit(token.id, operation, key.to_unsafe, key.bytesize, value.to_unsafe, value.bytesize))
  end

  def self.http(packet : Bytes, &completion : Reply -> Nil) : Operation
    raise ArgumentError.new("HTTP packet exceeds the transport limit") if packet.size > 1_048_576
    token = register(completion)
    accept(token, LibAndroidServices.android_host_http_submit(token.id, packet.to_unsafe, packet.size))
  end

  def self.secrets(operation : Int32, key : String, value : String = "", &completion : Reply -> Nil) : Operation
    raise ArgumentError.new("Secret identifier/value exceeds the transport limit") if key.bytesize > 512 || value.bytesize > 65_536
    token = register(completion)
    accept(token, LibAndroidServices.android_host_secrets_submit(token.id, operation, key.to_unsafe, key.bytesize, value.to_unsafe, value.bytesize))
  end

  def self.notifications(packet : Bytes, &completion : Reply -> Nil) : Operation
    raise ArgumentError.new("Notification packet exceeds the transport limit") if packet.size > 2194
    token = register(completion)
    accept(token, LibAndroidServices.android_host_notifications_submit(token.id, packet.to_unsafe, packet.size))
  end

  def self.files(operation : Int32, path : String, data : Bytes = Bytes.empty, &completion : Reply -> Nil) : Operation
    raise ArgumentError.new("File path/data exceeds the transport limit") if path.bytesize > 1024 || data.size > 1_048_576
    token = register(completion)
    accept(token, LibAndroidServices.android_host_files_submit(token.id, operation, path.to_unsafe, path.bytesize, data.to_unsafe, data.size))
  end

  private def self.register(completion : Proc(Reply, Nil)) : Operation
    raise Unavailable.new("Android service queue is full") if @@pending.size >= 64
    raise Unavailable.new("Android operation identifiers exhausted") if @@next_id == Int64::MAX.to_u64
    @@next_id += 1
    token = Operation.new(@@next_id)
    @@pending[token.id] = Pending.new(token, completion)
    token
  end

  private def self.accept(token : Operation, accepted : Int32) : Operation
    if accepted == 0
      @@pending.delete(token.id)
      token.finish
      raise Unavailable.new("Android service is unavailable or closed")
    end
    token
  end

  def self.complete(id : UInt64, status : Int32, bytes : Bytes) : Nil
    pending = @@pending.delete(id) || return
    pending.operation.finish
    pending.completion.call(Reply.new(Status.from_value(status), bytes.dup))
  end

  def self.pending_count : Int32
    @@pending.size
  end
end

fun crystal_android_service_complete(id : UInt64, status : Int32, data : UInt8*, size : Int32) : Int32
  raise ArgumentError.new("Invalid Android completion size") unless 0 <= size <= 1_048_576
  UI::Android::Services.complete(id, status, Bytes.new(data, size))
  1
  rescue error
    UI::Android::Application.log_exception(error)
    0
end

fun crystal_android_service_pending_count : Int32
  UI::Android::Services.pending_count
end
