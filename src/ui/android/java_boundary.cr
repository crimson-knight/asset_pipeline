{% if flag?(:android) %}
  module UI::Android
    class PendingJavaException < Exception
    end

    module JavaBoundary
      lib LibExceptionStatus
        fun android_exception_pending(env : Void*) : Int32
      end

      # Leave the VM's original Throwable pending. Only Crystal frames unwind;
      # their ensure/rescue blocks release native ownership before JNI returns
      # and Android delivers the original exception to the Kotlin host.
      def self.check!(env : Void*) : Nil
        raise PendingJavaException.new("Android JNI operation failed") if LibExceptionStatus.android_exception_pending(env) != 0
      end
    end
  end
{% end %}
