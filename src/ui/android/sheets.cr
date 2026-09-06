require "json"
require "../views/sheet"

module UI::Android::Sheets
  # The single-surface application keeps only the retired Crystal declaration
  # across a render, never a live Android View or a callback registry token.
  # Java compares bounded presentation identities after mounting the next tree.
  @@retired : UI::Sheet? = nil

  def self.stage_retirement(view : UI::Sheet) : Nil
    raise "Unreconciled Android sheet retirement" if @@retired
    @@retired = view
  end

  def self.finish_retirement(dismissed : Bool) : Bool
    previous = @@retired
    @@retired = nil # Clear before invoking application code, including failures.
    return false unless dismissed && previous
    previous.__android_did_dismiss
    true
  end

  def self.discard_retirement : Nil
    @@retired = nil
  end

  def self.detent(value : Symbol) : Int32
    case value
    when :small  then 0
    when :medium then 1
    when :large  then 2
    else
      raise ArgumentError.new("Android sheet detents must be small, medium or large; custom heights require a separate explicit API")
    end
  end

  def self.encode(view : UI::Sheet, lifecycle : UInt64, changed : UInt64) : String
    values = view.detents.map { |value| detent(value) }
    selected = detent(view.selected_detent)
    title = view.accessibility_label || "Sheet"
    unless 1 <= values.size <= 3 && values.uniq.size == values.size && values.includes?(selected) &&
           title.valid_encoding? && !title.strip.empty? && title.bytesize <= 4096 &&
           0 < lifecycle <= Int64::MAX && 0 < changed <= Int64::MAX && lifecycle != changed
      raise ArgumentError.new("Invalid Android sheet presentation contract")
    end
    JSON.build do |json|
      json.object do
        json.field "version", 1
        json.field "title", title
        json.field "detents", values
        json.field "selected", selected
        json.field "drag", view.shows_drag_indicator
        json.field "locked", view.interactive_dismiss_disabled
        json.field "lifecycle", lifecycle
        json.field "detent", changed
      end
    end
  end
end
