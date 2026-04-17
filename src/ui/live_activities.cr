require "json"

module UI
  # Metadata for an ActivityKit-style update intent.
  #
  # This is export-only. It keeps the intent that would be handed off to a host
  # or build step without pretending to render anything in-app.
  class LiveActivityUpdateIntent
    property identifier : String
    property title : String?
    property subtitle : String?
    property system_image : String?
    property user_info : Hash(String, String)
    property is_enabled : Bool

    def initialize(
      @identifier : String,
      @title : String? = nil,
      @subtitle : String? = nil,
      @system_image : String? = nil,
      user_info : Hash(String, String) = {} of String => String,
      @is_enabled : Bool = true
    )
      raise ArgumentError.new("live activity update intent identifier cannot be blank") if @identifier.strip.empty?
      @user_info = user_info.dup
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "title", @title if @title
        json.field "subtitle", @subtitle if @subtitle
        json.field "system_image", @system_image if @system_image
        json.field "user_info", @user_info unless @user_info.empty?
        json.field "is_enabled", @is_enabled
      end
    end
  end

  # Export-only ActivityKit-style state for one live activity.
  #
  # The state is deliberately plain data: an attributes type, the exported
  # attributes payload, the content-state payload, and an optional update
  # intent.
  class LiveActivity
    property identifier : String
    property attributes_type : String
    property attributes : Hash(String, String)
    property content_state : Hash(String, String)
    property update_intent : LiveActivityUpdateIntent?
    property is_active : Bool

    def initialize(
      @attributes_type : String,
      identifier : String? = nil,
      attributes : Hash(String, String) = {} of String => String,
      content_state : Hash(String, String) = {} of String => String,
      @update_intent : LiveActivityUpdateIntent? = nil,
      @is_active : Bool = true
    )
      raise ArgumentError.new("live activity attributes type cannot be blank") if @attributes_type.strip.empty?
      @identifier = if identifier && !identifier.empty?
                      identifier
                    else
                      slugify(@attributes_type)
                    end
      @attributes = attributes.dup
      @content_state = content_state.dup
    end

    def add_attribute(key : String, value : String) : String
      @attributes[key] = value
      value
    end

    def add_content_state_field(key : String, value : String) : String
      @content_state[key] = value
      value
    end

    def attach_update_intent(intent : LiveActivityUpdateIntent) : LiveActivityUpdateIntent
      @update_intent = intent
      intent
    end

    def build_update_intent(
      identifier : String,
      title : String? = nil,
      subtitle : String? = nil,
      system_image : String? = nil,
      user_info : Hash(String, String) = {} of String => String,
      is_enabled : Bool = true
    ) : LiveActivityUpdateIntent
      attach_update_intent(
        LiveActivityUpdateIntent.new(
          identifier,
          title: title,
          subtitle: subtitle,
          system_image: system_image,
          user_info: user_info,
          is_enabled: is_enabled
        )
      )
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "attributes_type", @attributes_type
        json.field "attributes", @attributes
        json.field "content_state", @content_state
        json.field "update_intent" do
          if intent = @update_intent
            intent.to_payload(json)
          else
            json.null
          end
        end
        json.field "is_active", @is_active
      end
    end

    private def slugify(value : String) : String
      normalized = value
        .gsub(/([a-z\d])([A-Z])/, "\\1-\\2")
        .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1-\\2")
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/^-+|-+$/, "")
      normalized.empty? ? "live-activity" : normalized
    end
  end

  # Container for exported live activity state.
  #
  # This is the app-facing surface for building ActivityKit-style state dumps
  # for a host, build step, or validation pipeline.
  class LiveActivities
    property application_name : String
    property bundle_identifier : String?
    property activities : Array(LiveActivity)

    def initialize(@application_name : String, @bundle_identifier : String? = nil, activities : Array(LiveActivity)? = nil)
      @activities = activities || [] of LiveActivity
    end

    def add_activity(
      attributes_type : String,
      identifier : String? = nil,
      attributes : Hash(String, String) = {} of String => String,
      content_state : Hash(String, String) = {} of String => String,
      update_intent : LiveActivityUpdateIntent? = nil,
      is_active : Bool = true,
      &block : LiveActivity -> Nil
    ) : LiveActivity
      activity = LiveActivity.new(
        attributes_type,
        identifier: identifier,
        attributes: attributes,
        content_state: content_state,
        update_intent: update_intent,
        is_active: is_active
      )
      yield activity
      @activities << activity
      activity
    end

    def add_activity(
      attributes_type : String,
      identifier : String? = nil,
      attributes : Hash(String, String) = {} of String => String,
      content_state : Hash(String, String) = {} of String => String,
      update_intent : LiveActivityUpdateIntent? = nil,
      is_active : Bool = true
    ) : LiveActivity
      activity = LiveActivity.new(
        attributes_type,
        identifier: identifier,
        attributes: attributes,
        content_state: content_state,
        update_intent: update_intent,
        is_active: is_active
      )
      @activities << activity
      activity
    end

    def add_activity(activity : LiveActivity) : LiveActivity
      @activities << activity
      activity
    end

    def remove_activity(identifier : String) : Bool
      before = @activities.size
      @activities.reject! { |entry| entry.identifier == identifier }
      before != @activities.size
    end

    def clear : Nil
      @activities.clear
    end

    def find_activity(identifier : String) : LiveActivity?
      @activities.find { |entry| entry.identifier == identifier }
    end

    def to_payload : String
      JSON.build do |json|
        json.object do
          json.field "application_name", @application_name
          json.field "bundle_identifier", @bundle_identifier if @bundle_identifier
          json.field "activities" do
            json.array do
              @activities.each { |activity| activity.to_payload(json) }
            end
          end
        end
      end
    end
  end
end
