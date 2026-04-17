require "json"

module UI
  # Metadata for one App Shortcut declaration.
  #
  # The visible presentation of App Shortcuts belongs to Apple's system
  # surfaces. This model keeps the intent in Crystal so host code can export a
  # practical metadata payload for AppIntents / shortcut registration without
  # pretending the capability is a drawable UI::View.
  class AppShortcutParameter
    property name : String
    property prompt : String?
    property type : String?
    property default_value : String?
    property is_required : Bool

    def initialize(
      @name : String,
      @prompt : String? = nil,
      @type : String? = nil,
      @default_value : String? = nil,
      @is_required : Bool = true
    )
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "name", @name
        json.field "prompt", @prompt if @prompt
        json.field "type", @type if @type
        json.field "default_value", @default_value if @default_value
        json.field "is_required", @is_required
      end
    end
  end

  # A single shortcut declaration.
  #
  # This is intentionally a metadata object, not a rendered view. It packages
  # the user-facing title, phrases, and parameters that a host app can later
  # export into AppIntents or a similar integration layer.
  class AppShortcut
    property identifier : String
    property title : String
    property subtitle : String?
    property summary : String?
    property icon : String?
    property phrases : Array(String)
    property parameters : Array(AppShortcutParameter)
    property is_enabled : Bool
    property is_discoverable : Bool

    def initialize(
      @title : String,
      identifier : String? = nil,
      @subtitle : String? = nil,
      @summary : String? = nil,
      @icon : String? = nil,
      phrases : Array(String)? = nil,
      parameters : Array(AppShortcutParameter)? = nil,
      @is_enabled : Bool = true,
      @is_discoverable : Bool = true
    )
      @identifier = if identifier && !identifier.empty?
                      identifier
                    else
                      slugify(@title)
                    end
      @phrases = phrases || [] of String
      @parameters = parameters || [] of AppShortcutParameter
    end

    def add_phrase(phrase : String) : String
      @phrases << phrase
      phrase
    end

    def add_parameter(
      name : String,
      prompt : String? = nil,
      type : String? = nil,
      default_value : String? = nil,
      is_required : Bool = true
    ) : AppShortcutParameter
      parameter = AppShortcutParameter.new(
        name,
        prompt: prompt,
        type: type,
        default_value: default_value,
        is_required: is_required
      )
      @parameters << parameter
      parameter
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "title", @title
        json.field "subtitle", @subtitle if @subtitle
        json.field "summary", @summary if @summary
        json.field "icon", @icon if @icon
        json.field "phrases" do
          json.array do
            @phrases.each { |phrase| json.string phrase }
          end
        end
        json.field "parameters" do
          json.array do
            @parameters.each { |parameter| parameter.to_payload(json) }
          end
        end
        json.field "is_enabled", @is_enabled
        json.field "is_discoverable", @is_discoverable
      end
    end

    private def slugify(value : String) : String
      normalized = value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      normalized.empty? ? "shortcut" : normalized
    end
  end

  # App-shell metadata container for App Shortcuts.
  #
  # The model is intentionally export-oriented. Host code can collect one or
  # more shortcuts here and serialize the declaration payload into a build
  # step, Intents bundle, or other platform integration layer.
  class AppShortcuts
    property application_name : String
    property bundle_identifier : String?
    property shortcuts : Array(AppShortcut)

    def initialize(@application_name : String, @bundle_identifier : String? = nil, shortcuts : Array(AppShortcut)? = nil)
      @shortcuts = shortcuts || [] of AppShortcut
    end

    def add_shortcut(
      title : String,
      identifier : String? = nil,
      subtitle : String? = nil,
      summary : String? = nil,
      icon : String? = nil,
      phrases : Array(String)? = nil,
      parameters : Array(AppShortcutParameter)? = nil,
      is_enabled : Bool = true,
      is_discoverable : Bool = true,
      &block : AppShortcut -> Nil
    ) : AppShortcut
      shortcut = AppShortcut.new(
        title,
        identifier: identifier,
        subtitle: subtitle,
        summary: summary,
        icon: icon,
        phrases: phrases,
        parameters: parameters,
        is_enabled: is_enabled,
        is_discoverable: is_discoverable
      )
      yield shortcut
      @shortcuts << shortcut
      shortcut
    end

    def add_shortcut(
      title : String,
      identifier : String? = nil,
      subtitle : String? = nil,
      summary : String? = nil,
      icon : String? = nil,
      phrases : Array(String)? = nil,
      parameters : Array(AppShortcutParameter)? = nil,
      is_enabled : Bool = true,
      is_discoverable : Bool = true
    ) : AppShortcut
      shortcut = AppShortcut.new(
        title,
        identifier: identifier,
        subtitle: subtitle,
        summary: summary,
        icon: icon,
        phrases: phrases,
        parameters: parameters,
        is_enabled: is_enabled,
        is_discoverable: is_discoverable
      )
      @shortcuts << shortcut
      shortcut
    end

    def add_shortcut(shortcut : AppShortcut) : AppShortcut
      @shortcuts << shortcut
      shortcut
    end

    def remove_shortcut(identifier : String) : Bool
      before = @shortcuts.size
      @shortcuts.reject! { |entry| entry.identifier == identifier }
      before != @shortcuts.size
    end

    def clear : Nil
      @shortcuts.clear
    end

    def find_shortcut(identifier : String) : AppShortcut?
      @shortcuts.find { |entry| entry.identifier == identifier }
    end

    def to_payload : String
      JSON.build do |json|
        json.object do
          json.field "application_name", @application_name
          json.field "bundle_identifier", @bundle_identifier if @bundle_identifier
          json.field "shortcuts" do
            json.array do
              @shortcuts.each { |shortcut| shortcut.to_payload(json) }
            end
          end
        end
      end
    end
  end
end
