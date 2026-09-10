# Core Tier A candidates the plan names that no Android fixture exercised:
# secure field, text area, progress views, activity indicator, divider and
# icon button. Values stay in Crystal; the host re-renders after callbacks.
module AndroidBasicsFixture
  @@secret = ""
  @@notes = "Line one\nLine two"
  @@progress = 0.35
  @@taps = 0
  @@bold = false
  @@link_taps = 0

  def self.reset
    @@secret = ""; @@notes = "Line one\nLine two"; @@progress = 0.35; @@taps = 0; @@bold = false; @@link_taps = 0
  end

  def self.mark(view : UI::View, id : String) : UI::View
    view.test_id = id
    view.state_key = id
    view
  end

  def self.build : UI::View
    root = UI::VStack.new(6.0, UI::Alignment::Leading)
    root.state_key = "basics-screen"
    root << mark(UI::Label.new("Native basics").tap { |v| v.accessibility_role = :header }, "basics-heading")

    secret = UI::SecureField.new("Passcode", text: @@secret) { |text| @@secret = text; nil }
    root << mark(secret, "basics-secret")
    root << mark(UI::Label.new("Secret length: #{@@secret.size}"), "basics-secret-echo")

    notes = UI::TextArea.new("Notes") { |text| @@notes = text; nil }
    notes.text = @@notes
    root << mark(notes, "basics-notes")
    root << mark(UI::Label.new("Lines: #{@@notes.lines.size}"), "basics-notes-echo")

    divider = UI::Divider.new
    divider.minimum_height = divider.maximum_height = 2.0
    divider.fill_horizontal = true
    root << mark(divider, "basics-divider")

    linear = UI::ProgressView.new(@@progress)
    linear.fill_horizontal = true
    root << mark(linear, "basics-progress")
    root << mark(UI::ProgressView.new(nil).tap { |v| v.fill_horizontal = true }, "basics-progress-indeterminate")
    root << mark(UI::ProgressView.new(0.5, UI::ProgressStyle::Circular), "basics-progress-circular")
    root << mark(UI::ActivityIndicator.new, "basics-spinner")
    root << mark(UI::ActivityIndicator.new(false), "basics-spinner-paused")
    root << mark(UI::Button.new("Advance") { @@progress = 0.75; nil }, "basics-advance")

    icon = UI::IconButton.new("contrast") { @@taps += 1; nil }
    icon.accessibility_label = "Add item"
    root << mark(icon, "basics-icon")
    root << mark(UI::Label.new("Icon taps: #{@@taps}"), "basics-icon-echo")

    toggle = UI::ToggleButton.new("Bold", @@bold) { |on| @@bold = on; nil }
    root << mark(toggle, "basics-toggle-button")
    root << mark(UI::Label.new("Bold: #{@@bold}"), "basics-toggle-echo")

    link = UI::LinkButton.new("Docs", "https://example.invalid/docs")
    link.on_tap = -> { @@link_taps += 1; nil }
    root << mark(link, "basics-link")
    root << mark(UI::Label.new("Link taps: #{@@link_taps}"), "basics-link-echo")
    root << mark(UI::LinkButton.new("Open site", "https://example.invalid/"), "basics-link-browser")
    root
  end
end
