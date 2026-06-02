# Crystal models for UserNotifications authorization status and request payloads.
# Export-only: a host adapter performs the actual UNUserNotificationCenter calls.

require "json"

module UI
  # User-Notifications authorization status, mirroring
  # `UNAuthorizationStatus` (iOS / macOS) and the Android equivalents.
  # The `Unsupported` variant marks targets where the user-notifications
  # framework has no analog (e.g. web before the Notification API
  # adapter ships).
  enum NotificationAuthorizationStatus
    NotDetermined
    Denied
    Authorized
    Provisional
    Ephemeral
    Unsupported
  end

  # Declarative description of a local user notification.
  #
  # The Crystal model captures the payload the host adapter passes to
  # `UNUserNotificationCenter.add(request:withCompletionHandler:)`.
  # Construction validates basics; scheduling is the host's
  # responsibility.
  #
  # ```
  # req = UI::NotificationRequest.new(
  #   title: "Standup in 5 minutes",
  #   body: "Daily standup starts at 10:00",
  #   subtitle: "Engineering",
  #   delay_seconds: 300.0,
  # )
  # ```
  class NotificationRequest
    # Stable identifier for the notification. Reuse to update an
    # existing notification; defaults to a millisecond-resolution UUID.
    property identifier : String

    # Main heading text (UNNotificationContent.title).
    property title : String

    # Optional sub-heading (UNNotificationContent.subtitle).
    property subtitle : String?

    # Body text shown below the title.
    property body : String

    # Trigger delay in seconds. Floored to 0.25s for non-repeating;
    # repeating notifications are minimum 60s per platform requirements.
    property delay_seconds : Float64

    # Whether the trigger repeats at `delay_seconds` cadence.
    property repeats : Bool

    # Whether to play the default sound when delivered.
    property sound : Bool

    # Optional app-icon badge count to apply on delivery.
    property badge : Int32?

    # Optional thread / grouping identifier (UNNotificationContent.threadIdentifier).
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

    # Returns the actual trigger delay enforced by platform constraints:
    # floored to 0.25s on non-repeating, 60s on repeating per Apple's
    # UNTimeIntervalNotificationTrigger contract.
    def effective_delay_seconds : Float64
      base = @delay_seconds > 0.0 ? @delay_seconds : 0.25
      @repeats && base < 60.0 ? 60.0 : base
    end
  end

  # Declarative description of a notification action button (the
  # interactive affordances rendered in expanded / banner notifications).
  # Mirrors `UNNotificationAction` / `UNTextInputNotificationAction`.
  class NotificationAction
    # Stable identifier dispatched back to the app when the action is
    # tapped. Must be non-blank.
    property identifier : String

    # Button label shown in the notification UI. Must be non-blank.
    property title : String

    # Action kind. `"default"` produces a `UNNotificationAction`;
    # `"text_input"` produces a `UNTextInputNotificationAction`. Normalized
    # via `normalize_kind` so callers can pass `"Text Input"` / `"text-input"`.
    property kind : String

    # Apple `UNNotificationActionOptions` flag names (string form),
    # e.g. `"foreground"`, `"destructive"`, `"authentication_required"`.
    # Stored sorted + de-duplicated.
    property options : Array(String)

    # `UNTextInputNotificationAction.textInputButtonTitle` — only used
    # when `kind == "text_input"`.
    property text_input_button_title : String?

    # Placeholder text shown in the inline text input field — only
    # used when `kind == "text_input"`.
    property text_input_placeholder : String?

    # Whether the action should be rendered as enabled. The host adapter
    # is responsible for honoring this when registering categories.
    property is_enabled : Bool

    def initialize(
      @identifier : String,
      @title : String,
      @kind : String = "default",
      options : Array(String) = [] of String,
      @text_input_button_title : String? = nil,
      @text_input_placeholder : String? = nil,
      @is_enabled : Bool = true
    )
      raise ArgumentError.new("notification action identifier cannot be blank") if @identifier.strip.empty?
      raise ArgumentError.new("notification action title cannot be blank") if @title.strip.empty?
      @kind = normalize_kind(@kind)
      @options = options.map(&.strip).reject(&.empty?).uniq.sort
    end

    # Adds a `UNNotificationActionOptions` flag (e.g. `"destructive"`)
    # to `options`, preserving sort/unique ordering. Returns the
    # normalized option string (or empty string if the input was blank).
    def add_option(option : String) : String
      normalized = option.strip
      return normalized if normalized.empty?

      @options = (@options + [normalized]).uniq.sort
      normalized
    end

    # Serializes the action into the JSON manifest format consumed by
    # `NotificationsCatalog#export_manifest`. Called by the catalog
    # exporter, rarely directly.
    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "title", @title
        json.field "kind", @kind
        json.field "options" do
          json.array do
            @options.each { |option| json.string option }
          end
        end
        json.field "text_input_button_title", @text_input_button_title if @text_input_button_title
        json.field "text_input_placeholder", @text_input_placeholder if @text_input_placeholder
        json.field "is_enabled", @is_enabled
      end
    end

    # Emits a Swift literal expression for this action that can be
    # pasted into a host-side category registration helper. `indent`
    # is the leading whitespace width (in spaces) for the outer
    # constructor — inner argument lines are indented +4. Used by
    # `NotificationsCatalog#export_swift_scaffold`.
    def to_swift_scaffold(indent : Int32 = 12) : String
      indent_str = " " * indent
      String.build do |output|
        if text_input?
          output << indent_str << "UNTextInputNotificationAction(\n"
          output << indent_str << "    identifier: " << swift_string_literal(@identifier) << ",\n"
          output << indent_str << "    title: " << swift_string_literal(@title) << ",\n"
          output << indent_str << "    options: " << swift_options_literal << ",\n"
          output << indent_str << "    textInputButtonTitle: " << swift_string_literal(@text_input_button_title || "Send") << ",\n"
          output << indent_str << "    textInputPlaceholder: " << swift_string_literal(@text_input_placeholder || "") << "\n"
          output << indent_str << ")"
        else
          output << indent_str << "UNNotificationAction(\n"
          output << indent_str << "    identifier: " << swift_string_literal(@identifier) << ",\n"
          output << indent_str << "    title: " << swift_string_literal(@title) << ",\n"
          output << indent_str << "    options: " << swift_options_literal << "\n"
          output << indent_str << ")"
        end
      end
    end

    private def normalize_kind(value : String) : String
      normalized = value.strip.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_+|_+$/, "")
      normalized.empty? ? "default" : normalized
    end

    private def text_input? : Bool
      @kind == "text_input"
    end

    private def swift_string_literal(value : String) : String
      String.build do |output|
        output << '"'
        value.each_char do |char|
          case char
          when '\\'
            output << "\\\\"
          when '"'
            output << "\\\""
          when '\n'
            output << "\\n"
          when '\r'
            output << "\\r"
          when '\t'
            output << "\\t"
          else
            output << char
          end
        end
        output << '"'
      end
    end

    private def swift_options_literal : String
      mapped = @options.map do |option|
        case option.downcase
        when "foreground" then ".foreground"
        when "destructive" then ".destructive"
        when "authenticationrequired" then ".authenticationRequired"
        when "authentication_required" then ".authenticationRequired"
        else
          nil
        end
      end.compact

      mapped.empty? ? "[]" : "[#{mapped.join(", ")}]"
    end
  end

  # Declarative description of a `UNNotificationCategory` — a named
  # grouping of `NotificationAction`s that get registered ahead of
  # notification delivery. Categories are matched on a notification's
  # `categoryIdentifier` to decide which action buttons to render.
  class NotificationCategory
    # Stable category identifier matched against
    # `UNMutableNotificationContent.categoryIdentifier`. Must be non-blank.
    property identifier : String

    # Ordered list of action buttons. Serialization paths sort by
    # action identifier for deterministic output.
    property actions : Array(NotificationAction)

    # SiriKit / App Intents identifiers this category should advertise
    # (`UNNotificationCategory.intentIdentifiers`). De-duplicated and
    # sorted on assignment.
    property intent_identifiers : Array(String)

    # Apple `UNNotificationCategoryOptions` flag names (string form),
    # e.g. `"custom_dismiss_action"`, `"allow_in_car_play"`,
    # `"hidden_previews_show_title"`. Sorted + de-duplicated.
    property options : Array(String)

    # Whether the category should be rendered as enabled when the host
    # registers the catalog.
    property is_enabled : Bool

    def initialize(
      @identifier : String,
      actions : Array(NotificationAction) = [] of NotificationAction,
      intent_identifiers : Array(String) = [] of String,
      options : Array(String) = [] of String,
      @is_enabled : Bool = true
    )
      raise ArgumentError.new("notification category identifier cannot be blank") if @identifier.strip.empty?
      @actions = actions.dup
      @intent_identifiers = intent_identifiers.map(&.strip).reject(&.empty?).uniq.sort
      @options = options.map(&.strip).reject(&.empty?).uniq.sort
    end

    # Appends a pre-built `NotificationAction` to this category. Returns
    # the same action for chaining.
    def add_action(action : NotificationAction) : NotificationAction
      @actions << action
      action
    end

    # Constructs a `NotificationAction` from primitives and appends it.
    # Convenience over building the action separately. Returns the new
    # action.
    def add_action(
      identifier : String,
      title : String,
      kind : String = "default",
      options : Array(String) = [] of String,
      text_input_button_title : String? = nil,
      text_input_placeholder : String? = nil,
      is_enabled : Bool = true
    ) : NotificationAction
      action = NotificationAction.new(
        identifier,
        title,
        kind: kind,
        options: options,
        text_input_button_title: text_input_button_title,
        text_input_placeholder: text_input_placeholder,
        is_enabled: is_enabled
      )
      add_action(action)
      action
    end

    # Adds an App Intents / SiriKit identifier to
    # `intent_identifiers`. Blank input is ignored and an empty string
    # returned. Otherwise returns the normalized identifier.
    def add_intent_identifier(identifier : String) : String
      normalized = identifier.strip
      return normalized if normalized.empty?

      @intent_identifiers = (@intent_identifiers + [normalized]).uniq.sort
      normalized
    end

    # Adds a `UNNotificationCategoryOptions` flag to `options`,
    # preserving sort/unique ordering.
    def add_option(option : String) : String
      normalized = option.strip
      return normalized if normalized.empty?

      @options = (@options + [normalized]).uniq.sort
      normalized
    end

    # Serializes the category (including its actions) into the JSON
    # manifest format consumed by `NotificationsCatalog#export_manifest`.
    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "actions" do
          json.array do
            sorted_actions.each { |action| action.to_payload(json) }
          end
        end
        json.field "intent_identifiers" do
          json.array do
            @intent_identifiers.each { |identifier| json.string identifier }
          end
        end
        json.field "options" do
          json.array do
            @options.each { |option| json.string option }
          end
        end
        json.field "is_enabled", @is_enabled
      end
    end

    # Emits a Swift literal expression for this category that can be
    # pasted into a host-side `UNUserNotificationCenter.setCategories`
    # call. `indent` is the leading whitespace width (in spaces) for
    # the outer constructor; inner argument lines are indented +4.
    # Action scaffolds are emitted at `indent + 8`.
    def to_swift_scaffold(indent : Int32 = 8) : String
      indent_str = " " * indent
      action_indent = indent_str + "    "
      String.build do |output|
        output << indent_str << "UNNotificationCategory(\n"
        output << action_indent << "identifier: " << swift_string_literal(@identifier) << ",\n"
        output << action_indent << "actions: [\n"
        sorted_actions.each do |action|
          output << action.to_swift_scaffold(indent + 8) << ",\n"
        end
        output << action_indent << "],\n"
        output << action_indent << "intentIdentifiers: ["
        output << @intent_identifiers.map { |identifier| swift_string_literal(identifier) }.join(", ")
        output << "],\n"
        output << action_indent << "options: " << swift_category_options_literal << "\n"
        output << indent_str << ")"
      end
    end

    private def sorted_actions : Array(NotificationAction)
      @actions.sort_by(&.identifier)
    end

    private def swift_string_literal(value : String) : String
      String.build do |output|
        output << '"'
        value.each_char do |char|
          case char
          when '\\'
            output << "\\\\"
          when '"'
            output << "\\\""
          when '\n'
            output << "\\n"
          when '\r'
            output << "\\r"
          when '\t'
            output << "\\t"
          else
            output << char
          end
        end
        output << '"'
      end
    end

    private def swift_category_options_literal : String
      mapped = @options.map do |option|
        case option.downcase
        when "custom_dismiss_action" then ".customDismissAction"
        when "allow_in_car_play" then ".allowInCarPlay"
        when "hidden_previews_show_title" then ".hiddenPreviewsShowTitle"
        when "hidden_previews_show_subtitle" then ".hiddenPreviewsShowSubtitle"
        else
          nil
        end
      end.compact

      mapped.empty? ? "[]" : "[#{mapped.join(", ")}]"
    end
  end

  # Top-level catalog of notification categories for an application.
  # Owns a `NotificationCategory` collection and renders both a JSON
  # manifest (for cross-target tooling) and a Swift scaffold (for
  # host-side `UNUserNotificationCenter` registration).
  class NotificationsCatalog
    # Human-readable application name (used in the Swift scaffold's
    # module name + header comments).
    property application_name : String

    # Optional CFBundleIdentifier used in the Swift scaffold header.
    property bundle_identifier : String?

    # All categories owned by the catalog. Serialization paths sort by
    # category identifier for deterministic output.
    property categories : Array(NotificationCategory)

    def initialize(@application_name : String, @bundle_identifier : String? = nil, categories : Array(NotificationCategory)? = nil)
      @categories = categories || [] of NotificationCategory
    end

    # Appends a pre-built `NotificationCategory`. Returns the same
    # category for chaining.
    def add_category(category : NotificationCategory) : NotificationCategory
      @categories << category
      category
    end

    # Block-form: constructs a category from primitives, yields it for
    # further configuration, then appends. Returns the new category.
    def add_category(
      identifier : String,
      actions : Array(NotificationAction) = [] of NotificationAction,
      intent_identifiers : Array(String) = [] of String,
      options : Array(String) = [] of String,
      is_enabled : Bool = true,
      &block : NotificationCategory -> Nil
    ) : NotificationCategory
      category = NotificationCategory.new(
        identifier,
        actions: actions,
        intent_identifiers: intent_identifiers,
        options: options,
        is_enabled: is_enabled
      )
      yield category
      @categories << category
      category
    end

    # Constructs a category from primitives and appends it. Returns
    # the new category.
    def add_category(
      identifier : String,
      actions : Array(NotificationAction) = [] of NotificationAction,
      intent_identifiers : Array(String) = [] of String,
      options : Array(String) = [] of String,
      is_enabled : Bool = true
    ) : NotificationCategory
      category = NotificationCategory.new(
        identifier,
        actions: actions,
        intent_identifiers: intent_identifiers,
        options: options,
        is_enabled: is_enabled
      )
      @categories << category
      category
    end

    # Removes every category whose `identifier` matches. Returns true
    # if at least one category was removed.
    def remove_category(identifier : String) : Bool
      before = @categories.size
      @categories.reject! { |entry| entry.identifier == identifier }
      before != @categories.size
    end

    # Returns the first category with the given `identifier`, or nil
    # if no category matches.
    def find_category(identifier : String) : NotificationCategory?
      @categories.find { |entry| entry.identifier == identifier }
    end

    # Removes every category from the catalog.
    def clear : Nil
      @categories.clear
    end

    # Serializes the entire catalog to a stable JSON manifest. The
    # category list is sorted by identifier so byte-level diffs of the
    # manifest are meaningful across runs.
    def export_manifest : String
      JSON.build do |json|
        json.object do
          json.field "application_name", @application_name
          json.field "bundle_identifier", @bundle_identifier if @bundle_identifier
          json.field "categories" do
            json.array do
              sorted_categories.each { |category| category.to_payload(json) }
            end
          end
        end
      end
    end

    # Renders the catalog as a Swift source file that can be pasted
    # into the host app to register categories with
    # `UNUserNotificationCenter`. The generated module name is derived
    # from `application_name`; categories are emitted in sorted order.
    def export_swift_scaffold : String
      String.build do |output|
        output << "import UserNotifications\n\n"
        output << "// Generated by asset_pipeline.\n"
        output << "// Application: " << @application_name << "\n"
        output << "// Bundle Identifier: " << @bundle_identifier << "\n" if @bundle_identifier
        output << "\n"
        output << "public enum " << swift_module_name << " {\n"
        if @categories.empty?
          output << "    // No notification categories were exported.\n"
        else
          output << "    public static var categories: Set<UNNotificationCategory> {\n"
          output << "        Set([\n"
          sorted_categories.each do |category|
            output << category.to_swift_scaffold(12) << ",\n"
          end
          output << "        ])\n"
          output << "    }\n\n"
          output << "    public static func register() {\n"
          output << "        UNUserNotificationCenter.current().setNotificationCategories(categories)\n"
          output << "    }\n"
        end
        output << "}\n"
      end
    end

    private def sorted_categories : Array(NotificationCategory)
      @categories.sort_by(&.identifier)
    end

    private def swift_module_name : String
      base = @application_name.strip
      base = "AssetPipeline" if base.empty?
      normalized = base
        .gsub(/([a-z\d])([A-Z])/, "\\1 \\2")
        .gsub(/[^A-Za-z0-9]+/, " ")
        .split(/\s+/)
        .map { |part| part.empty? ? "" : part[0].upcase + part[1..].downcase }
        .join
      normalized = "AssetPipeline" if normalized.empty?
      normalized = "AssetPipeline#{normalized}" if normalized.match(/^\d/)
      "#{normalized}Notifications"
    end
  end

  # Module-level facade for the User Notifications framework. The
  # macOS / iOS implementations bridge through the typed-C bridge to
  # `UNUserNotificationCenter`; every other target returns inert
  # defaults so cross-platform code can call the API unguarded.
  module Notifications
    extend self

    {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
      lib LibObjCBridge
        fun ap_notifications_authorization_status : Int64
        fun ap_notifications_request_authorization(alert : Int32, sound : Int32, badge : Int32, provisional : Int32) : Int32
        fun ap_notifications_schedule_local(identifier : UInt8*, title : UInt8*, subtitle : UInt8*, body : UInt8*, delay_seconds : Float64, badge : Int32, play_sound : Int32, repeats : Int32, thread_id : UInt8*) : Int32
        fun ap_notifications_remove_pending(identifier : UInt8*) : Void
        fun ap_notifications_remove_all_pending : Void
        fun ap_notifications_pending_count : Int32
        fun ap_notifications_has_pending(identifier : UInt8*) : Int32
      end
    {% end %}

    # Returns the current authorization status. On non-Apple targets,
    # returns `NotificationAuthorizationStatus::Unsupported`.
    def authorization_status : NotificationAuthorizationStatus
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        status_from_native(LibObjCBridge.ap_notifications_authorization_status)
      {% else %}
        NotificationAuthorizationStatus::Unsupported
      {% end %}
    end

    # Prompts the OS for notification authorization with the given
    # capability flags (alert + sound + badge by default). Returns true
    # on grant, false on denial or unsupported target. The call is
    # synchronous from Crystal's side — the host adapter blocks on the
    # underlying `requestAuthorization` callback.
    #
    # `provisional: true` requests `UNAuthorizationOptionProvisional` — quiet,
    # no-prompt authorization: the OS grants immediately (no permission dialog,
    # no user tap), and notifications are delivered quietly to Notification
    # Center until the user promotes or turns them off. Ideal for a low-friction
    # coach/agent that should be able to reach you without nagging on first run.
    def request_authorization(alert : Bool = true, sound : Bool = true, badge : Bool = true, provisional : Bool = false) : Bool
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibObjCBridge.ap_notifications_request_authorization(alert ? 1 : 0, sound ? 1 : 0, badge ? 1 : 0, provisional ? 1 : 0) == 1
      {% else %}
        false
      {% end %}
    end

    # Schedules a local notification by translating the `request` into
    # a `UNTimeIntervalNotificationTrigger` payload. Returns true if
    # the host accepted the schedule. On non-Apple targets returns
    # false without raising so cross-platform code can early-out
    # silently.
    def schedule(request : NotificationRequest) : Bool
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
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

    # Removes a single pending notification by identifier. No-op on
    # non-Apple targets.
    def remove_pending(identifier : String) : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibObjCBridge.ap_notifications_remove_pending(identifier.to_unsafe)
      {% end %}
    end

    # Removes all pending notifications scheduled by this app. No-op on
    # non-Apple targets.
    def remove_all_pending : Nil
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibObjCBridge.ap_notifications_remove_all_pending
      {% end %}
    end

    # Number of notification requests currently pending delivery. Pending
    # requests are tracked independently of authorization (auth gates
    # delivery, not scheduling), so a count increase is an honest signal that
    # `schedule` actually landed a request — usable as a functional-outcome
    # assertion without observing a delivered banner. Returns -1 when the
    # notification center is unavailable, 0 on non-Apple targets.
    def pending_count : Int32
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibObjCBridge.ap_notifications_pending_count
      {% else %}
        0
      {% end %}
    end

    # True when a pending notification with `identifier` exists — lets a caller
    # assert that ITS specific notification is scheduled, not merely that some
    # notification is. False on non-Apple targets / when the center is
    # unavailable.
    def has_pending?(identifier : String) : Bool
      {% if flag?(:macos) || flag?(:ios) || flag?(:watchos) %}
        LibObjCBridge.ap_notifications_has_pending(identifier.to_unsafe) == 1
      {% else %}
        false
      {% end %}
    end

    # Convenience wrapper: serializes `catalog` to a JSON manifest.
    # Equivalent to `catalog.export_manifest`.
    def export_manifest(catalog : NotificationsCatalog) : String
      catalog.export_manifest
    end

    # Convenience wrapper: serializes `catalog` to a Swift scaffold
    # source file. Equivalent to `catalog.export_swift_scaffold`.
    def export_swift_scaffold(catalog : NotificationsCatalog) : String
      catalog.export_swift_scaffold
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
