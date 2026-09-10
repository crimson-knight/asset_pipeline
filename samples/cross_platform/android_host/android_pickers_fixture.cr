# Picker Tier A candidates: a date picker with bounds and a 24-hour time
# picker. Both values live in Crystal; the host reports changes and re-renders.
module AndroidPickersFixture
  @@date = Time.utc(2026, 9, 6, 12, 0, 0)
  @@time = Time.utc(2000, 1, 1, 9, 30, 0)
  @@date_changes = 0
  @@time_changes = 0

  def self.reset
    @@date = Time.utc(2026, 9, 6, 12, 0, 0); @@time = Time.utc(2000, 1, 1, 9, 30, 0); @@date_changes = 0; @@time_changes = 0
  end

  def self.mark(view : UI::View, id : String) : UI::View
    view.test_id = id
    view.state_key = id
    view
  end

  def self.build : UI::View
    root = UI::VStack.new(6.0, UI::Alignment::Leading)
    root.state_key = "pickers-screen"
    root << mark(UI::Label.new("Native pickers").tap { |v| v.accessibility_role = :header }, "pickers-heading")

    date = UI::DatePicker.new do |value|
      @@date_changes += 1 if value != @@date
      @@date = value
      nil
    end
    date.selected_date = @@date
    date.minimum_date = Time.utc(2026, 1, 1)
    date.maximum_date = Time.utc(2026, 12, 31)
    root << mark(date, "pickers-date")
    root << mark(UI::Label.new("Date: #{@@date.to_s("%Y-%m-%d")}; changes: #{@@date_changes}"), "pickers-date-echo")

    time = UI::TimePicker.new(true) do |value|
      @@time_changes += 1 if value != @@time
      @@time = value
      nil
    end
    time.selected_time = @@time
    root << mark(time, "pickers-time")
    root << mark(UI::Label.new("Time: #{@@time.to_s("%H:%M")}; changes: #{@@time_changes}"), "pickers-time-echo")
    root
  end
end
