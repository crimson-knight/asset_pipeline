require "json"

module UI
  # Describes how a widget should be placed and refreshed on a specific
  # platform surface.
  #
  # This stays intentionally declarative. It records the widget family's
  # intended placement and timeline behavior so host tooling can export the
  # metadata into WidgetKit or another extension layer without pretending to
  # render the widget in-app.
  class WidgetPlacement
    property surface : String
    property families : Array(String)
    property timeline_intent : String
    property refresh_policy : String?
    property notes : String?

    def initialize(
      @surface : String,
      families : Array(String)? = nil,
      @timeline_intent : String = "snapshot",
      @refresh_policy : String? = nil,
      @notes : String? = nil
    )
      @families = families || [] of String
    end

    def add_family(family : String) : String
      @families << family
      family
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "surface", @surface
        json.field "families" do
          json.array do
            @families.each { |family| json.string family }
          end
        end
        json.field "timeline_intent", @timeline_intent
        json.field "refresh_policy", @refresh_policy if @refresh_policy
        json.field "notes", @notes if @notes
      end
    end
  end

  # A single widget declaration.
  #
  # The model is extension-oriented rather than visual. It captures the
  # widget's identity, a short summary, and the surfaces where the widget is
  # expected to appear.
  class Widget
    property identifier : String
    property title : String
    property summary : String?
    property placements : Array(WidgetPlacement)
    property is_enabled : Bool

    def initialize(
      @title : String,
      identifier : String? = nil,
      @summary : String? = nil,
      placements : Array(WidgetPlacement)? = nil,
      @is_enabled : Bool = true
    )
      @identifier = if identifier && !identifier.empty?
                      identifier
                    else
                      slugify(@title)
                    end
      @placements = placements || [] of WidgetPlacement
    end

    def add_placement(
      surface : String,
      families : Array(String)? = nil,
      timeline_intent : String = "snapshot",
      refresh_policy : String? = nil,
      notes : String? = nil,
      &block : WidgetPlacement -> Nil
    ) : WidgetPlacement
      placement = WidgetPlacement.new(
        surface,
        families: families,
        timeline_intent: timeline_intent,
        refresh_policy: refresh_policy,
        notes: notes
      )
      yield placement
      @placements << placement
      placement
    end

    def add_placement(
      surface : String,
      families : Array(String)? = nil,
      timeline_intent : String = "snapshot",
      refresh_policy : String? = nil,
      notes : String? = nil
    ) : WidgetPlacement
      placement = WidgetPlacement.new(
        surface,
        families: families,
        timeline_intent: timeline_intent,
        refresh_policy: refresh_policy,
        notes: notes
      )
      @placements << placement
      placement
    end

    def add_placement(placement : WidgetPlacement) : WidgetPlacement
      @placements << placement
      placement
    end

    def to_payload(json : JSON::Builder) : Nil
      json.object do
        json.field "identifier", @identifier
        json.field "title", @title
        json.field "summary", @summary if @summary
        json.field "placements" do
          json.array do
            @placements.each { |placement| placement.to_payload(json) }
          end
        end
        json.field "is_enabled", @is_enabled
      end
    end

    private def slugify(value : String) : String
      normalized = value.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-+|-+$/, "")
      normalized.empty? ? "widget" : normalized
    end
  end

  # Extension-oriented metadata container for widgets.
  #
  # The container is intentionally export-only. It gives build tooling a place
  # to collect widget declarations and serialize them into a manifest for the
  # eventual WidgetKit or system-extension integration layer.
  class Widgets
    property application_name : String
    property bundle_identifier : String?
    property widgets : Array(Widget)

    def initialize(@application_name : String, @bundle_identifier : String? = nil, widgets : Array(Widget)? = nil)
      @widgets = widgets || [] of Widget
    end

    def add_widget(
      title : String,
      identifier : String? = nil,
      summary : String? = nil,
      placements : Array(WidgetPlacement)? = nil,
      is_enabled : Bool = true,
      &block : Widget -> Nil
    ) : Widget
      widget = Widget.new(
        title,
        identifier: identifier,
        summary: summary,
        placements: placements,
        is_enabled: is_enabled
      )
      yield widget
      @widgets << widget
      widget
    end

    def add_widget(
      title : String,
      identifier : String? = nil,
      summary : String? = nil,
      placements : Array(WidgetPlacement)? = nil,
      is_enabled : Bool = true
    ) : Widget
      widget = Widget.new(
        title,
        identifier: identifier,
        summary: summary,
        placements: placements,
        is_enabled: is_enabled
      )
      @widgets << widget
      widget
    end

    def add_widget(widget : Widget) : Widget
      @widgets << widget
      widget
    end

    def remove_widget(identifier : String) : Bool
      before = @widgets.size
      @widgets.reject! { |entry| entry.identifier == identifier }
      before != @widgets.size
    end

    def find_widget(identifier : String) : Widget?
      @widgets.find { |entry| entry.identifier == identifier }
    end

    def clear : Nil
      @widgets.clear
    end

    def to_payload : String
      JSON.build do |json|
        json.object do
          json.field "application_name", @application_name
          json.field "bundle_identifier", @bundle_identifier if @bundle_identifier
          json.field "widgets" do
            json.array do
              @widgets.each { |widget| widget.to_payload(json) }
            end
          end
        end
      end
    end
  end
end
