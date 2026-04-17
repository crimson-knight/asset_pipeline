module UI
  enum NotificationAuthorizationStatus
    NotDetermined
    Denied
    Authorized
    Provisional
    Ephemeral
    Unsupported
  end

  class NotificationRequest
    property identifier : String
    property title : String
    property subtitle : String?
    property body : String
    property delay_seconds : Float64
    property repeats : Bool
    property sound : Bool
    property badge : Int32?
    property thread_id : String?

    def initialize(@title : String,
                   @body : String,
                   identifier : String? = nil,
                   @subtitle : String? = nil,
                   @delay_seconds : Float64 = 0.25,
                   @repeats : Bool = false,
                   @sound : Bool = true,
                   @badge : Int32? = nil,
                   @thread_id : String? = nil)
      @identifier = if identifier && !identifier.empty?
                      identifier
                    else
                      "ui-notification-#{Time.utc.to_unix_ms}"
                    end
    end

    def effective_delay_seconds : Float64
      base = @delay_seconds > 0.0 ? @delay_seconds : 0.25
      @repeats && base < 60.0 ? 60.0 : base
    end
  end

  module Notifications
    extend self

    {% if flag?(:darwin) %}
      lib LibObjCBridge
        fun ap_notifications_authorization_status : Int64
        fun ap_notifications_request_authorization(alert : Int32, sound : Int32, badge : Int32) : Int32
        fun ap_notifications_schedule_local(identifier : UInt8*, title : UInt8*, subtitle : UInt8*, body : UInt8*, delay_seconds : Float64, badge : Int32, play_sound : Int32, repeats : Int32, thread_id : UInt8*) : Int32
        fun ap_notifications_remove_pending(identifier : UInt8*) : Void
        fun ap_notifications_remove_all_pending : Void
      end
    {% end %}

    def authorization_status : NotificationAuthorizationStatus
      {% if flag?(:darwin) %}
        status_from_native(LibObjCBridge.ap_notifications_authorization_status)
      {% else %}
        NotificationAuthorizationStatus::Unsupported
      {% end %}
    end

    def request_authorization(alert : Bool = true, sound : Bool = true, badge : Bool = true) : Bool
      {% if flag?(:darwin) %}
        LibObjCBridge.ap_notifications_request_authorization(alert ? 1 : 0, sound ? 1 : 0, badge ? 1 : 0) == 1
      {% else %}
        false
      {% end %}
    end

    def schedule(request : NotificationRequest) : Bool
      {% if flag?(:darwin) %}
        subtitle_ptr = request.subtitle ? request.subtitle.not_nil!.to_unsafe : Pointer(UInt8).null
        thread_ptr = request.thread_id ? request.thread_id.not_nil!.to_unsafe : Pointer(UInt8).null
        badge_value = request.badge || -1

        LibObjCBridge.ap_notifications_schedule_local(
          request.identifier.to_unsafe,
          request.title.to_unsafe,
          subtitle_ptr,
          request.body.to_unsafe,
          request.effective_delay_seconds,
          badge_value,
          request.sound ? 1 : 0,
          request.repeats ? 1 : 0,
          thread_ptr
        ) == 1
      {% else %}
        false
      {% end %}
    end

    def remove_pending(identifier : String) : Nil
      {% if flag?(:darwin) %}
        LibObjCBridge.ap_notifications_remove_pending(identifier.to_unsafe)
      {% end %}
    end

    def remove_all_pending : Nil
      {% if flag?(:darwin) %}
        LibObjCBridge.ap_notifications_remove_all_pending
      {% end %}
    end

    private def status_from_native(status : Int64) : NotificationAuthorizationStatus
      case status
      when 0 then NotificationAuthorizationStatus::NotDetermined
      when 1 then NotificationAuthorizationStatus::Denied
      when 2 then NotificationAuthorizationStatus::Authorized
      when 3 then NotificationAuthorizationStatus::Provisional
      when 4 then NotificationAuthorizationStatus::Ephemeral
      else        NotificationAuthorizationStatus::Unsupported
      end
    end
  end
end
