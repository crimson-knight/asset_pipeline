module Voyager
  # Voyager — Component Gallery screen.
  #
  # A single scrollable catalog that demonstrates the asset_pipeline
  # cross-platform UI widgets rendering NATIVELY on the current device.
  # This is the "show me the library" surface: each section instantiates
  # a family of widgets with representative defaults so a developer can
  # see the real native rendering (Liquid Glass materials, SF Symbols,
  # system controls) without writing any code.
  #
  # Reached via the Settings screen ("Component Gallery") and the
  # `voyager-component-gallery` slug on the static-site web build.
  #
  # Widgets are instantiated for DISPLAY — interactive controls manage
  # their own SwiftUI local state when tapped; callbacks are intentionally
  # light so the gallery stays a pure showcase. iOS class-init-gap rules
  # apply: no Bool#to_s interpolation, no Time.local.
  class ComponentGalleryScreen < UI::Screen
    SLUG = "voyager-component-gallery"

    def build(context : UI::ScreenContext) : UI::View
      context.active_screen_class = self.class

      metrics = UI::DesignTokens::DeviceMetrics.current
      content_width = metrics.compact_horizontal? ? 340.0 : 480.0

      root = UI::VStack.new(spacing: 22.0)
      root.root_fill = true
      root.alignment = UI::Alignment::Leading
      root.padding = UI::EdgeInsets.new(
        top: 24.0 + metrics.safe_area_top_pt,
        trailing: 20.0 + metrics.safe_area_trailing_pt,
        bottom: 24.0 + metrics.safe_area_bottom_pt,
        leading: 20.0 + metrics.safe_area_leading_pt,
      )
      root.accessibility_label = "Component gallery"
      root.test_id = "voyager-component-gallery-root"

      title = UI::Label.new("Component Gallery")
      title.font = UI::Font.new(size: 28.0, weight: :bold)
      title.text_color_role = UI::LabelRole::Primary
      title.test_id = "voyager-gallery-title"
      root << title.as(UI::View)

      subtitle = UI::Label.new("Live native rendering of the asset_pipeline UI widgets on this device. Every interactive widget is wired — interact and watch the readout.")
      subtitle.font = UI::Font.new(size: 14.0, weight: :regular)
      subtitle.text_color_role = UI::LabelRole::Secondary
      root << subtitle.as(UI::View)

      # Shared readout — updates for every wired showcase widget below, so
      # each one visibly DOES something when you interact with it.
      last_event = UI::Label.new("Last interaction: #{GalleryState.last_event}")
      last_event.font = UI::Font.new(size: 14.0, weight: :semibold)
      last_event.text_color_role = UI::LabelRole::Primary
      last_event.test_id = "voyager-gallery-last-event"
      root << last_event.as(UI::View)

      # Section table — each entry is {name, description, builder}. Built
      # + added in order. VOYAGER_GALLERY_MAX_SECTION (diagnostic env)
      # caps how many sections are built/added so a crash can be bisected
      # by section without recompiling.
      sections = [
        {"Live Interaction — tap to see it work",
         "These widgets are wired to the controller: each interaction dispatches an action, mutates state, and re-renders. The readout below updates live, proving the widgets function (not just render).",
         -> { live_section(content_width) }},
        {"Buttons & Actions",
         "Tappable controls. Prominent is the primary call-to-action; Secondary/Destructive convey role; Icon/Link/Toggle/Menu are specialized button styles.",
         -> { buttons_section(content_width) }},
        {"Selection Controls",
         "Pick one or more values. Toggle/Checkbox are binary; SegmentedControl/RadioGroup/Picker choose one option from a set.",
         -> { selection_section(content_width) }},
        {"Value Inputs",
         "Adjust a continuous or bounded value. Slider/Stepper set numbers; DatePicker/ColorPicker pick a date or color.",
         -> { value_section(content_width) }},
        {"Text Entry",
         "Capture typed input. TextField is single-line; SecureField masks; SearchField adds search affordances; TextArea is multi-line.",
         -> { text_section(content_width) }},
        {"Feedback & Progress",
         "Communicate status. ProgressView/ActivityIndicator show ongoing work; RatingIndicator/Gauge display a value.",
         -> { feedback_section(content_width) }},
        {"Shapes",
         "Geometric primitives for custom drawing and decoration. Each takes a fill color and explicit size.",
         -> { shapes_section }},
        {"Imagery (SF Symbols)",
         "Image renders asset-catalog images or, as here, Apple SF Symbols by name.",
         -> { imagery_section }},
        {"Containers",
         "Group and elevate content. Card and Surface provide grouped backgrounds with system materials.",
         -> { containers_section(content_width) }},
        {"More Controls & Display",
         "TimePicker sets a time; DisclosureGroup expands/collapses; RichText composes styled runs; PageControl shows paged position.",
         -> { more_section(content_width) }},
        {"Layout",
         "Structure primitives. ZStack overlays children; Grid arranges cells in rows and columns.",
         -> { layout_section(content_width) }},
        {"Data & Indicators",
         "Visualize values. ChartView plots a series; ActivityRings shows ring progress; Snackbar is a transient status bar.",
         -> { data_section(content_width) }},
        {"Drawing",
         "Vector drawing. PathView strokes and fills a custom path built from move/line/curve segments.",
         -> { drawing_section }},
        {"Watch — Complication (cross-platform fallback)",
         "ComplicationWithWebFallback renders a real watchOS WidgetKit complication on -Dwatchos and, on every other target, a card-style preview of the same content. UI::Complication itself is compile-gated to watchOS (naming it off-watch is a compile error).",
         -> { complication_section }},
        {"Layout — Fluid (resizable column)",
         "Phase B: a label with UI::Fluid native width (min 200, ideal 280, max 340). It grows with available space up to its max, then wraps — a readable column that resizes instead of sprawling across the full section rail. Maps to the existing min>=/max<= Auto-Layout pins (no NSStackView replacement).",
         -> { fluid_section }},
      ]

      limit = ENV["VOYAGER_GALLERY_MAX_SECTION"]?.try(&.to_i?) || sections.size
      sections.each_with_index do |entry, i|
        break if i >= limit
        name, description, builder = entry
        root << section(name, description, content_width, builder.call)
      end

      back = UI::Button.new("Back")
      back.role = :secondary
      back.accessibility_label = "Back"
      back.test_id = "voyager-gallery-back"
      back.minimum_width = content_width
      back.maximum_width = content_width
      back.on_tap = -> { Voyager.dispatch(:back) }
      root << back.as(UI::View)

      root.as(UI::View)
    end

    # ------------------------------------------------------------------
    # Section chrome — a header label + divider + the widget column,
    # width-pinned so controls don't stretch past the content rail.
    # ------------------------------------------------------------------
    private def section(name : String, description : String, width : Float64, widgets : Array(UI::View)) : UI::View
      col = UI::VStack.new(spacing: 12.0)
      col.alignment = UI::Alignment::Leading
      col.minimum_width = width
      col.maximum_width = width

      header = UI::Label.new(name)
      header.font = UI::Font.new(size: 18.0, weight: :semibold)
      header.text_color_role = UI::LabelRole::Primary
      col << header.as(UI::View)

      desc = UI::Label.new(description)
      desc.font = UI::Font.new(size: 12.0, weight: :regular)
      desc.text_color_role = UI::LabelRole::Secondary
      col << desc.as(UI::View)

      col << UI::Divider.new(:horizontal).as(UI::View)

      widgets.each { |w| col << w }
      col.as(UI::View)
    end

    # Dispatch a one-line interaction event to the shared readout. Every
    # wired showcase widget calls this so interacting with it produces a
    # visible result, proving the widget functions.
    private def emit(text : String) : Nil
      Voyager.dispatch(:gallery_event, {"text" => text})
    end

    # Caption + widget, stacked. Gives unlabeled widgets a readable name.
    private def captioned(caption : String, widget : UI::View) : UI::View
      box = UI::VStack.new(spacing: 4.0)
      box.alignment = UI::Alignment::Leading
      label = UI::Label.new(caption)
      label.font = UI::Font.new(size: 12.0, weight: :regular)
      label.text_color_role = UI::LabelRole::Tertiary
      box << label.as(UI::View)
      box << widget
      box.as(UI::View)
    end

    # Watch complication — demonstrates the cross-platform companion. On this
    # (non-watchOS) build it renders the card-style preview fallback; on
    # -Dwatchos it would delegate to the native WidgetKit complication.
    private def complication_section : Array(UI::View)
      out = [] of UI::View
      comp = UI::ComplicationWithWebFallback.new(
        kind: :next_todos,
        content: UI::Label.new("2 todos due today").as(UI::View),
        family: UI::ComplicationFamily::AccessoryRectangular,
      )
      comp.test_id = "voyager-gallery-complication"
      comp.accessibility_label = "Next todos complication"
      out << captioned("ComplicationWithWebFallback (preview)", comp.as(UI::View))
      out
    end

    # Phase B — UI::Fluid native width demo. A long label with a fluid width
    # range; the renderer maps it to the existing min>=/max<= constraint pins, so
    # the label wraps at <= max (340pt) instead of filling the full section rail
    # (~480pt). The AX test asserts the rendered width is capped (proving the
    # max<= constraint engaged) — fluid actually does something, not just compiles.
    private def fluid_section : Array(UI::View)
      out = [] of UI::View
      label = UI::Label.new(
        "This column uses UI::Fluid native width (min 200, ideal 280, max 340): it " \
        "grows with available space up to its maximum, then wraps — a readable " \
        "column that resizes instead of sprawling across the full section rail."
      )
      label.font = UI::Font.new(size: 13.0, weight: :regular)
      label.test_id = "voyager-gallery-fluid-label"
      label.accessibility_label = "Fluid width demo label"
      # Fluid width goes on the CONTAINER (containers run apply_common_properties,
      # where the Fluid→min>=/max<= mapping lives; leaf facades like Label do not).
      # Capping the column at max 340 wraps the long label inside it at <=340,
      # which the AX test measures.
      column = UI::VStack.new(spacing: 0.0)
      column.fluid_width = UI::Fluid.px(200, 280, 340)
      column.test_id = "voyager-gallery-fluid-column"
      column << label.as(UI::View)
      out << column.as(UI::View)
      out
    end

    # ------------------------------------------------------------------
    # Live, wired widgets — each dispatches an action that mutates
    # GalleryState and re-renders, so the readout updates on interaction.
    # This is the proof that the catalog widgets FUNCTION on-device.
    # ------------------------------------------------------------------
    private def live_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      # Live readout — one label per tracked value, with stable test_ids
      # so an XCUITest can assert the text changes after interaction.
      taps = UI::Label.new("Taps: #{GalleryState.tap_count}")
      taps.font = UI::Font.new(size: 15.0, weight: :semibold)
      taps.text_color_role = UI::LabelRole::Primary
      taps.test_id = "voyager-gallery-live-taps"
      out << taps.as(UI::View)

      toggle_state = UI::Label.new(GalleryState.toggle_on ? "Toggle: ON" : "Toggle: OFF")
      toggle_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      toggle_state.text_color_role = UI::LabelRole::Primary
      toggle_state.test_id = "voyager-gallery-live-toggle-state"
      out << toggle_state.as(UI::View)

      mode_state = UI::Label.new("Mode: #{GalleryState.segment_label}")
      mode_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      mode_state.text_color_role = UI::LabelRole::Primary
      mode_state.test_id = "voyager-gallery-live-mode-state"
      out << mode_state.as(UI::View)

      step_state = UI::Label.new("Stepper: #{GalleryState.stepper_value}")
      step_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      step_state.text_color_role = UI::LabelRole::Primary
      step_state.test_id = "voyager-gallery-live-stepper-state"
      out << step_state.as(UI::View)

      tab_state = UI::Label.new("Tab: #{GalleryState.tab_label}")
      tab_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      tab_state.text_color_role = UI::LabelRole::Primary
      tab_state.test_id = "voyager-gallery-live-tab-state"
      out << tab_state.as(UI::View)

      color_state = UI::Label.new(GalleryState.color_label)
      color_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      color_state.text_color_role = UI::LabelRole::Primary
      color_state.test_id = "voyager-gallery-live-color-state"
      out << color_state.as(UI::View)

      # Captured-text readout for the Text Entry section's inputs. Those
      # inputs store their real typed value into GalleryState.captured_text
      # WITHOUT rerendering (to avoid losing keyboard focus); tapping "Tap
      # me" below triggers the rerender that surfaces it here. NO
      # accessibility_label, so the behavior test reads its text via
      # XCUIElement.label.
      captured_state = UI::Label.new(GalleryState.captured_text)
      captured_state.font = UI::Font.new(size: 15.0, weight: :semibold)
      captured_state.text_color_role = UI::LabelRole::Primary
      captured_state.test_id = "voyager-gallery-captured-text"
      out << captured_state.as(UI::View)

      # Wired Button — increments the tap counter.
      tap_btn = UI::Button.new("Tap me", style: UI::ButtonStyle::Prominent)
      tap_btn.accessibility_label = "Tap me to increment the counter"
      tap_btn.test_id = "voyager-gallery-live-tap-button"
      tap_btn.minimum_width = width
      tap_btn.maximum_width = width
      tap_btn.on_tap = -> { Voyager.dispatch(:gallery_tap) }
      out << tap_btn.as(UI::View)

      # Wired Toggle — flips Toggle: ON/OFF in the readout.
      live_toggle = UI::Toggle.new(label: "Live toggle", is_on: GalleryState.toggle_on)
      live_toggle.accessibility_label = "Live toggle"
      live_toggle.test_id = "voyager-gallery-live-toggle"
      live_toggle.minimum_width = width
      live_toggle.maximum_width = width
      live_toggle.on_change = ->(value : Bool) {
        Voyager.dispatch(:gallery_toggle, {"on" => value ? "true" : "false"})
      }
      out << live_toggle.as(UI::View)

      # Wired SegmentedControl — updates Mode in the readout.
      live_seg = UI::SegmentedControl.new(segments: GalleryState.segment_labels, selected_index: GalleryState.segment_index)
      live_seg.accessibility_label = "Live segmented control"
      live_seg.test_id = "voyager-gallery-live-segmented"
      live_seg.minimum_width = width
      live_seg.maximum_width = width
      live_seg.on_change = ->(index : Int32) {
        Voyager.dispatch(:gallery_segment, {"index" => index.to_s})
      }
      out << captioned("SegmentedControl (wired)", live_seg.as(UI::View))

      # Wired Stepper — updates Stepper value in the readout.
      live_step = UI::Stepper.new(minimum: 0.0, maximum: 20.0, value: GalleryState.stepper_value.to_f)
      live_step.accessibility_label = "Live stepper"
      live_step.test_id = "voyager-gallery-live-stepper"
      live_step.on_change = ->(value : Float64) {
        Voyager.dispatch(:gallery_stepper, {"value" => value.to_i.to_s})
      }
      out << captioned("Stepper (wired)", live_step.as(UI::View))

      # Wired TabView — selecting a tab updates the "Tab:" readout. Proves
      # the tab-change token now threads through to Crystal.
      live_tabs = UI::TabView.new(
        tabs: [
          UI::TabView::Tab.new(label: "Home", icon: "house", content: UI::Label.new("Home tab content")),
          UI::TabView::Tab.new(label: "Stats", icon: "chart.bar", content: UI::Label.new("Stats tab content")),
          UI::TabView::Tab.new(label: "Profile", icon: "person", content: UI::Label.new("Profile tab content")),
        ],
        selected_index: GalleryState.tab_index,
      )
      live_tabs.accessibility_label = "Live tab view"
      live_tabs.test_id = "voyager-gallery-live-tabview"
      live_tabs.minimum_width = width
      live_tabs.maximum_width = width
      live_tabs.on_change = ->(index : Int32) {
        Voyager.dispatch(:gallery_tab, {"index" => index.to_s})
      }
      out << captioned("TabView (wired)", live_tabs.as(UI::View))

      # Wired ColorPicker — updates the Color readout with the NEW pick
      # (the picked UI::Color's RGB), proving the colour value channel.
      live_color = UI::ColorPicker.new
      live_color.label = "Live color"
      live_color.selected_color = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
      live_color.supports_alpha = true
      live_color.accessibility_label = "Live color picker"
      live_color.test_id = "voyager-gallery-live-color"
      live_color.on_change = ->(c : UI::Color) {
        Voyager.dispatch(:gallery_color, {
          "rgb" => "#{(c.r * 255).round.to_i},#{(c.g * 255).round.to_i},#{(c.b * 255).round.to_i}",
        })
      }
      out << captioned("ColorPicker (wired)", live_color.as(UI::View))

      out
    end

    # ------------------------------------------------------------------
    private def buttons_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      prominent = UI::Button.new("Prominent Button", style: UI::ButtonStyle::Prominent)
      prominent.accessibility_label = "Prominent button sample"
      prominent.test_id = "voyager-gallery-button-prominent"
      prominent.minimum_width = width
      prominent.maximum_width = width
      prominent.on_tap = -> { emit("Prominent Button tapped") }
      out << prominent.as(UI::View)

      secondary = UI::Button.new("Secondary Button")
      secondary.role = :secondary
      secondary.accessibility_label = "Secondary button sample"
      secondary.test_id = "voyager-gallery-button-secondary"
      secondary.on_tap = -> { emit("Secondary Button tapped") }
      out << secondary.as(UI::View)

      destructive = UI::Button.new("Destructive Button")
      destructive.role = :destructive
      destructive.accessibility_label = "Destructive button sample"
      destructive.test_id = "voyager-gallery-button-destructive"
      destructive.on_tap = -> { emit("Destructive Button tapped") }
      out << destructive.as(UI::View)

      row = UI::HStack.new(spacing: 16.0)
      row.alignment = UI::Alignment::Center

      icon = UI::IconButton.new("square.and.arrow.up")
      icon.accessibility_label = "Share icon button"
      icon.test_id = "voyager-gallery-iconbutton"
      icon.on_tap = -> { emit("IconButton tapped") }
      row << icon.as(UI::View)

      link = UI::LinkButton.new("Open Link", "https://example.com")
      link.accessibility_label = "Link button sample"
      link.test_id = "voyager-gallery-linkbutton"
      link.on_tap = -> { emit("LinkButton tapped") }
      row << link.as(UI::View)

      toggle_btn = UI::ToggleButton.new("Bookmark", is_selected: true)
      toggle_btn.accessibility_label = "Toggle button sample"
      toggle_btn.test_id = "voyager-gallery-togglebutton"
      toggle_btn.on_toggle = ->(on : Bool) { emit(on ? "ToggleButton selected" : "ToggleButton deselected") }
      row << toggle_btn.as(UI::View)
      out << row.as(UI::View)

      menu = UI::MenuButton.new("Menu Button")
      menu.accessibility_label = "Menu button sample"
      menu.test_id = "voyager-gallery-menubutton"
      menu.add_item("First action") { emit("MenuButton: First action") }
      menu.add_item("Second action") { emit("MenuButton: Second action") }
      menu.add_item("Delete", is_destructive: true) { emit("MenuButton: Delete") }
      out << menu.as(UI::View)

      out
    end

    private def selection_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      toggle = UI::Toggle.new(label: "Toggle", is_on: true)
      toggle.accessibility_label = "Toggle sample"
      toggle.test_id = "voyager-gallery-toggle"
      toggle.minimum_width = width
      toggle.maximum_width = width
      toggle.on_change = ->(v : Bool) { emit(v ? "Toggle → on" : "Toggle → off") }
      out << toggle.as(UI::View)

      checkbox = UI::Checkbox.new(label: "Checkbox", is_checked: true)
      checkbox.accessibility_label = "Checkbox sample"
      checkbox.test_id = "voyager-gallery-checkbox"
      checkbox.on_change = ->(v : Bool) { emit(v ? "Checkbox → checked" : "Checkbox → unchecked") }
      out << checkbox.as(UI::View)

      seg = UI::SegmentedControl.new(segments: ["List", "Grid", "Columns"], selected_index: 1)
      seg.accessibility_label = "Segmented control sample"
      seg.test_id = "voyager-gallery-segmented"
      seg.minimum_width = width
      seg.maximum_width = width
      seg.on_change = ->(i : Int32) { emit("Segmented → index #{i}") }
      out << captioned("SegmentedControl", seg.as(UI::View))

      radio = UI::RadioGroup.new(options: ["Low", "Medium", "High"], selected_index: 0)
      radio.accessibility_label = "Radio group sample"
      radio.test_id = "voyager-gallery-radiogroup"
      radio.on_change = ->(i : Int32) { emit("RadioGroup → index #{i}") }
      out << captioned("RadioGroup", radio.as(UI::View))

      picker = UI::Picker.new(options: ["Red", "Green", "Blue"], selected_index: 2)
      picker.label = "Color"
      picker.accessibility_label = "Picker sample"
      picker.test_id = "voyager-gallery-picker"
      picker.on_change = ->(i : Int32) { emit("Picker → index #{i}") }
      out << captioned("Picker", picker.as(UI::View))

      out
    end

    private def value_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      slider = UI::Slider.new(minimum: 0.0, maximum: 100.0, value: 65.0)
      slider.accessibility_label = "Slider sample"
      slider.test_id = "voyager-gallery-slider"
      slider.minimum_width = width
      slider.maximum_width = width
      slider.on_change = ->(v : Float64) { emit("Slider → #{v.to_i}") }
      out << captioned("Slider", slider.as(UI::View))

      stepper = UI::Stepper.new(minimum: 0.0, maximum: 10.0, value: 3.0)
      stepper.accessibility_label = "Stepper sample"
      stepper.test_id = "voyager-gallery-stepper"
      stepper.on_change = ->(v : Float64) { emit("Stepper → #{v.to_i}") }
      out << captioned("Stepper", stepper.as(UI::View))

      date = UI::DatePicker.new(UI::DatePickerMode::Date)
      date.label = "Date"
      date.style = UI::DatePickerStyle::Compact
      date.accessibility_label = "Date picker sample"
      date.test_id = "voyager-gallery-datepicker"
      date.selected_date = Time.utc
      date.on_change = ->(_t : Time) { emit("DatePicker changed") }
      out << captioned("DatePicker", date.as(UI::View))

      color = UI::ColorPicker.new
      color.label = "Accent color"
      color.accessibility_label = "Color picker sample"
      color.test_id = "voyager-gallery-colorpicker"
      color.on_change = ->(_c : UI::Color) { emit("ColorPicker changed") }
      out << captioned("ColorPicker", color.as(UI::View))

      out
    end

    private def text_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      # Each text input's on_change stores the REAL typed string into
      # GalleryState.captured_text WITHOUT dispatching — so we do NOT
      # rerender mid-keystroke. (Rerendering on every keystroke destroys
      # the field's keyboard focus: NativeView reuse does not preserve
      # first-responder across a rebuild — see GalleryState.captured_text
      # and the "captured text" readout in the Live Interaction section.)
      # The behavior test types a full word, then taps the live "Tap me"
      # button once to trigger a single rerender that surfaces the captured
      # value — proving the typed text round-tripped to the Crystal handler
      # (the SecureField value-drop bug class).

      field = UI::TextField.new(placeholder: "Text field")
      field.accessibility_label = "Text field sample"
      field.test_id = "voyager-gallery-textfield"
      field.minimum_width = width
      field.maximum_width = width
      field.on_change = ->(v : String) { GalleryState.captured_text = "TextField: #{v}"; nil }
      out << field.as(UI::View)

      secure = UI::SecureField.new(placeholder: "Password")
      secure.accessibility_label = "Secure field sample"
      secure.test_id = "voyager-gallery-securefield"
      secure.minimum_width = width
      secure.maximum_width = width
      out << secure.as(UI::View)

      search = UI::SearchField.new(placeholder: "Search")
      search.accessibility_label = "Search field sample"
      search.test_id = "voyager-gallery-searchfield"
      search.minimum_width = width
      search.maximum_width = width
      search.on_change = ->(v : String) { GalleryState.captured_text = "Search: #{v}"; nil }
      out << search.as(UI::View)

      area = UI::TextArea.new(placeholder: "Multi-line text area")
      area.accessibility_label = "Text area sample"
      area.test_id = "voyager-gallery-textarea"
      area.minimum_width = width
      area.maximum_width = width
      area.minimum_height = 80.0
      area.on_change = ->(v : String) { GalleryState.captured_text = "TextArea: #{v}"; nil }
      out << captioned("TextArea", area.as(UI::View))

      editor = UI::TextEditor.new(placeholder: "Rich text editor")
      editor.accessibility_label = "Text editor sample"
      editor.test_id = "voyager-gallery-texteditor"
      editor.minimum_width = width
      editor.maximum_width = width
      editor.minimum_height = 80.0
      editor.on_change = ->(v : String) { GalleryState.captured_text = "TextEditor: #{v}"; nil }
      out << captioned("TextEditor", editor.as(UI::View))

      # ComboBox — value-drop fix: on_change is now wired (iOS) via the raw
      # UITextField string channel. Capture-without-rerender like the other
      # text inputs; the "Tap me" button reveals the captured value.
      combo = UI::ComboBox.new(
        value: "",
        options: ["Apple", "Banana", "Cherry"],
        placeholder: "Fruit",
        width: width,
      )
      combo.accessibility_label = "Combo box sample"
      combo.test_id = "voyager-gallery-combobox"
      combo.on_change = ->(v : String) { GalleryState.captured_text = "ComboBox: #{v}"; nil }
      out << captioned("ComboBox", combo.as(UI::View))

      out
    end

    private def feedback_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      bar = UI::ProgressView.new(value: 0.6, style: UI::ProgressStyle::Linear)
      bar.accessibility_label = "Linear progress sample"
      bar.minimum_width = width
      bar.maximum_width = width
      out << captioned("ProgressView (linear)", bar.as(UI::View))

      spinner_row = UI::HStack.new(spacing: 16.0)
      spinner_row.alignment = UI::Alignment::Center

      spinner = UI::ProgressView.new(value: nil, style: UI::ProgressStyle::Circular)
      spinner.accessibility_label = "Circular progress sample"
      spinner_row << spinner.as(UI::View)

      activity = UI::ActivityIndicator.new(is_animating: true, size: :medium)
      activity.accessibility_label = "Activity indicator sample"
      spinner_row << activity.as(UI::View)

      rating = UI::RatingIndicator.new(value: 3.0, max: 5)
      rating.accessibility_label = "Rating indicator sample"
      spinner_row << rating.as(UI::View)
      out << captioned("Spinner · Activity · Rating", spinner_row.as(UI::View))

      gauge = UI::Gauge.new(value: 72.0, minimum_value: 0.0, maximum_value: 100.0, label: "Speed")
      gauge.accessibility_label = "Gauge sample"
      gauge.minimum_width = width
      gauge.maximum_width = width
      out << captioned("Gauge", gauge.as(UI::View))

      out
    end

    # Shape primitives render as bare UIViews whose width/height come from
    # the common min/max sizing properties — the `size`/`width`/`height`
    # constructor args only drive cornerRadius, NOT the frame. So each
    # shape MUST be explicitly dimensioned here or it collapses to 0x0 and
    # renders invisible. Distinct fills make the family legible at a glance.
    private def shapes_section : Array(UI::View)
      row = UI::HStack.new(spacing: 16.0)
      row.alignment = UI::Alignment::Center

      circle = UI::Circle.new(size: 56.0)
      circle.fill_color = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
      size_shape(circle, 56.0, 56.0)
      circle.accessibility_label = "Circle"
      row << circle.as(UI::View)

      rect = UI::Rectangle.new(width: 72.0, height: 56.0)
      rect.fill_color = UI::Color.new(r: 0.20, g: 0.78, b: 0.35)
      size_shape(rect, 72.0, 56.0)
      rect.accessibility_label = "Rectangle"
      row << rect.as(UI::View)

      rounded = UI::RoundedRectangle.new(corner_radius: 12.0, width: 72.0, height: 56.0)
      rounded.fill_color = UI::Color.new(r: 1.0, g: 0.58, b: 0.0)
      size_shape(rounded, 72.0, 56.0)
      rounded.accessibility_label = "Rounded rectangle"
      row << rounded.as(UI::View)

      capsule = UI::Capsule.new(width: 88.0, height: 40.0)
      capsule.fill_color = UI::Color.new(r: 0.69, g: 0.32, b: 0.87)
      size_shape(capsule, 88.0, 40.0)
      capsule.accessibility_label = "Capsule"
      row << capsule.as(UI::View)

      [captioned("Circle · Rectangle · RoundedRectangle · Capsule", row.as(UI::View))]
    end

    private def size_shape(view : UI::View, w : Float64, h : Float64) : Nil
      view.minimum_width = w
      view.maximum_width = w
      view.minimum_height = h
      view.maximum_height = h
    end

    private def imagery_section : Array(UI::View)
      row = UI::HStack.new(spacing: 20.0)
      row.alignment = UI::Alignment::Center

      ["leaf.fill", "sparkles", "sun.max.fill", "cloud.rain.fill", "star.fill"].each do |symbol|
        img = UI::Image.new(symbol)
        img.accessibility_label = "#{symbol} symbol"
        row << img.as(UI::View)
      end

      [captioned("Image (system symbols)", row.as(UI::View))]
    end

    private def layout_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      # ZStack — a label overlaid on a filled rounded rectangle.
      z = UI::ZStack.new(alignment: UI::Alignment::Center)
      z_bg = UI::RoundedRectangle.new(corner_radius: 12.0, width: 220.0, height: 72.0)
      z_bg.fill_color = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
      size_shape(z_bg, 220.0, 72.0)
      z << z_bg.as(UI::View)
      z_label = UI::Label.new("ZStack overlay")
      z_label.font = UI::Font.new(size: 15.0, weight: :semibold)
      z_label.text_color_role = UI::LabelRole::Primary
      z << z_label.as(UI::View)
      z.accessibility_label = "Z stack sample"
      z.test_id = "voyager-gallery-zstack"
      # Reserve the ZStack's own height so the following Grid doesn't draw
      # over it (ZStack overlays its children and has no intrinsic height).
      z.minimum_height = 72.0
      z.maximum_height = 72.0
      z.minimum_width = 220.0
      z.maximum_width = 220.0
      out << captioned("ZStack (overlay)", z.as(UI::View))

      # Grid — 2 columns x 2 rows of labels.
      grid = UI::Grid.new(columns: [UI::Grid::Column.new, UI::Grid::Column.new])
      grid.row_spacing = 8.0
      grid.column_spacing = 16.0
      grid.accessibility_label = "Grid sample"
      grid.test_id = "voyager-gallery-grid"
      grid.add_row([grid_cell("Cell A1"), grid_cell("Cell B1")])
      grid.add_row([grid_cell("Cell A2"), grid_cell("Cell B2")])
      out << captioned("Grid (2×2)", grid.as(UI::View))

      out
    end

    private def drawing_section : Array(UI::View)
      out = [] of UI::View

      # Canvas — immediate-mode replay: a stroked blue triangle plus a
      # filled orange disc (begin_path / move / line / arc / stroke / fill).
      canvas = UI::Canvas.new(width: 220.0, height: 120.0)
      canvas.begin_path
      canvas.move_to(20.0, 100.0)
      canvas.line_to(70.0, 20.0)
      canvas.line_to(120.0, 100.0)
      canvas.close_path
      canvas.stroke(UI::Color.new(r: 0.0, g: 0.478, b: 1.0), width: 3.0)
      canvas.begin_path
      canvas.arc(175.0, 60.0, 35.0)
      canvas.fill(UI::Color.new(r: 1.0, g: 0.58, b: 0.0))
      canvas.accessibility_label = "Canvas sample"
      canvas.test_id = "voyager-gallery-canvas"
      canvas.minimum_width = 220.0
      canvas.maximum_width = 220.0
      canvas.minimum_height = 120.0
      canvas.maximum_height = 120.0
      out << captioned("Canvas (triangle + disc)", canvas.as(UI::View))

      # PathView — a filled + stroked custom triangle, drawn via the iOS
      # CAShapeLayer path renderer.
      path = UI::PathView.new(width: 140.0, height: 120.0)
      path.fill_color = UI::Color.new(r: 1.0, g: 0.58, b: 0.0)
      path.stroke_color = UI::Color.new(r: 0.0, g: 0.0, b: 0.0)
      path.stroke_width = 2.0
      path.move_to(70.0, 12.0)
      path.line_to(128.0, 108.0)
      path.line_to(12.0, 108.0)
      path.close
      path.accessibility_label = "Path view sample"
      path.test_id = "voyager-gallery-path"
      path.minimum_width = 140.0
      path.maximum_width = 140.0
      path.minimum_height = 120.0
      path.maximum_height = 120.0
      out << captioned("PathView (filled triangle)", path.as(UI::View))

      out
    end

    private def grid_cell(text : String) : UI::View
      l = UI::Label.new(text)
      l.font = UI::Font.new(size: 14.0, weight: :regular)
      l.text_color_role = UI::LabelRole::Secondary
      l.as(UI::View)
    end

    private def data_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      chart = UI::ChartView.new
      chart.chart_type = :bar
      chart.title = "This week"
      chart.data_points = [
        UI::ChartDataPoint.new(label: "Mon", value: 3.0),
        UI::ChartDataPoint.new(label: "Tue", value: 5.0),
        UI::ChartDataPoint.new(label: "Wed", value: 2.0),
        UI::ChartDataPoint.new(label: "Thu", value: 6.0),
        UI::ChartDataPoint.new(label: "Fri", value: 4.0),
      ]
      chart.accessibility_label = "Chart sample"
      chart.test_id = "voyager-gallery-chart"
      chart.minimum_width = width
      chart.maximum_width = width
      chart.minimum_height = 180.0
      out << captioned("ChartView (bar)", chart.as(UI::View))

      rings = UI::ActivityRings.new(move: 0.8, exercise: 0.6, stand: 0.45)
      rings.accessibility_label = "Activity rings sample"
      rings.test_id = "voyager-gallery-rings"
      rings.minimum_width = 130.0
      rings.maximum_width = 130.0
      rings.minimum_height = 130.0
      rings.maximum_height = 130.0
      out << captioned("ActivityRings", rings.as(UI::View))

      snack = UI::Snackbar.new("Todo saved", "Undo")
      snack.is_presented = true
      snack.accessibility_label = "Snackbar sample"
      snack.test_id = "voyager-gallery-snackbar"
      snack.minimum_width = width
      snack.maximum_width = width
      out << captioned("Snackbar", snack.as(UI::View))

      out
    end

    private def more_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      time = UI::TimePicker.new(shows_24_hour: false)
      time.label = "Time"
      time.accessibility_label = "Time picker sample"
      time.test_id = "voyager-gallery-timepicker"
      time.selected_time = Time.utc
      time.on_change = ->(_t : Time) { emit("TimePicker changed") }
      out << captioned("TimePicker", time.as(UI::View))

      disc_body = UI::Label.new("Hidden detail revealed by expanding the group.")
      disc_body.font = UI::Font.new(size: 13.0, weight: :regular)
      disc_body.text_color_role = UI::LabelRole::Secondary
      disclosure = UI::DisclosureGroup.new("Disclosure group", expanded: false, content: [disc_body.as(UI::View)])
      disclosure.accessibility_label = "Disclosure group sample"
      disclosure.test_id = "voyager-gallery-disclosure"
      disclosure.minimum_width = width
      disclosure.maximum_width = width
      out << disclosure.as(UI::View)

      rich = UI::RichText.new
      rich.add_span("Rich", bold: true)
      rich.add_span("Text", italic: true, color: UI::Color.new(r: 0.0, g: 0.478, b: 1.0))
      rich.add_span(" composes styled runs.")
      rich.accessibility_label = "Rich text sample"
      out << captioned("RichText", rich.as(UI::View))

      page = UI::PageControl.new(total: 5, current: 2)
      page.accessibility_label = "Page control sample"
      page.test_id = "voyager-gallery-pagecontrol"
      out << captioned("PageControl", page.as(UI::View))

      out
    end

    private def containers_section(width : Float64) : Array(UI::View)
      out = [] of UI::View

      card_body = UI::VStack.new(spacing: 6.0)
      card_body.alignment = UI::Alignment::Leading
      card_body.padding = UI::EdgeInsets.new(top: 14.0, trailing: 16.0, bottom: 14.0, leading: 16.0)
      card_title = UI::Label.new("Card")
      card_title.font = UI::Font.new(size: 16.0, weight: :semibold)
      card_title.text_color_role = UI::LabelRole::Primary
      card_body_text = UI::Label.new("A grouped surface with elevation and rounded corners.")
      card_body_text.font = UI::Font.new(size: 13.0, weight: :regular)
      card_body_text.text_color_role = UI::LabelRole::Secondary
      card_body << card_title.as(UI::View)
      card_body << card_body_text.as(UI::View)

      card = UI::Card.new(card_body.as(UI::View))
      card.accessibility_label = "Card sample"
      card.minimum_width = width
      card.maximum_width = width
      out << card.as(UI::View)

      surface_body = UI::VStack.new(spacing: 6.0)
      surface_body.alignment = UI::Alignment::Leading
      surface_body.padding = UI::EdgeInsets.new(top: 14.0, trailing: 16.0, bottom: 14.0, leading: 16.0)
      surface_title = UI::Label.new("Surface")
      surface_title.font = UI::Font.new(size: 16.0, weight: :semibold)
      surface_title.text_color_role = UI::LabelRole::Primary
      surface_body << surface_title.as(UI::View)

      surface = UI::Surface.new(surface_body.as(UI::View))
      surface.accessibility_label = "Surface sample"
      surface.minimum_width = width
      surface.maximum_width = width
      out << surface.as(UI::View)

      out
    end
  end
end
