{% if flag?(:android) %}
  @[Link("log")]
  lib LibAndroidCallbackLog
    fun write = __android_log_write(priority : Int32, tag : UInt8*, text : UInt8*) : Int32
  end
{% end %}

module UI::Android
  # Checked native entrypoints must finish inside Crystal before reporting an
  # application error to Java. Do not unwind an exception through a C/JNI frame.
  # Log the callback kind and exception class, never arbitrary input/message data.
  module CallbackBoundary
    def self.protect(kind : String, &block : ->) : Int32
      yield
      1
    rescue error
      # A diagnostic failure must not turn a contained application failure
      # back into an exception crossing the native boundary.
      begin
        report(kind, error)
      rescue
        {% if flag?(:android) %}
          LibAndroidCallbackLog.write(6, "AssetPipelineNative", "Crystal callback failed; diagnostics unavailable")
        {% end %}
      end
      0
    end

    private def self.report(kind : String, error : Exception) : Nil
      {% if flag?(:android) %}
        message = "Crystal #{kind} callback failed (#{error.class})"
        LibAndroidCallbackLog.write(6, "AssetPipelineNative", message.to_unsafe)
      {% end %}
    end
  end
end
