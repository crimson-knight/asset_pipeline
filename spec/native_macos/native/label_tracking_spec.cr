require "spec"
require "../../../src/ui"
require "../../../src/ui/ax_test"

{% if flag?(:macos) %}
  # Proves `UI::Label#tracking` reaches the pixels the AppKit renderer draws.
  # Each Label is drawn offscreen into an sRGB bitmap at 2x; the ink width is
  # measured from the pixels whose alpha passes half coverage, so the result
  # depends only on where the glyphs landed, not on any property.
  #
  # Tracking adds its space after every character, so the ink (first glyph's
  # left edge to last glyph's right edge) grows by (glyph count - 1) x
  # tracking, while the layout width the Text asks for grows by glyph count x
  # tracking: SwiftUI keeps the trailing space after the last glyph.
  lib LabelTrackingSpecBridge
    fun ap_spec_tracking_window_new(view : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_tracking_capture(window : Void*, scale : Float64, out_rgba : UInt8*, capacity : Int64, out_size : Int32*) : Int32
    fun ap_spec_tracking_fitting_size(window : Void*, width : Float64*, height : Float64*) : Void
    fun ap_spec_tracking_application_is_active : Int32
    fun ap_spec_tracking_window_is_key(window : Void*) : Int32
    fun ap_spec_tracking_window_close(window : Void*) : Void
  end

  # Selection, copy, and pasteboard helpers from the selectable Label bridge.
  lib LabelTrackingCopyBridge
    fun ap_spec_pump_label_run_loop : Void
    fun ap_spec_ax_point_hits_selectable_text(window_ptr : Void*, ax_x : Float64, ax_y : Float64) : Int32
    fun ap_spec_triple_click_at_ax_point(window_ptr : Void*, ax_x : Float64, ax_y : Float64) : Int32
    fun ap_spec_copy_from_first_responder(window_ptr : Void*) : Int32
    fun ap_spec_pasteboard_snapshot : Void*
    fun ap_spec_pasteboard_restore(snapshot_ptr : Void*) : Void
    fun ap_spec_pasteboard_write_string(text : UInt8*) : Void
    fun ap_spec_pasteboard_copy_string : UInt8*
  end

  private TRACKED_TEXT        = "STANDING BY"
  private FONT_SIZE           = 11.0
  private TRACKING_POINTS     = FONT_SIZE * 0.12
  private CAPTURE_SCALE       = 2.0
  private CAPTURE_CAPACITY    = 4_i64 * 2048 * 2048
  private INK_ALPHA_THRESHOLD =   128
  private PIXEL_TOLERANCE     =   1.0
  private WINDOW_WIDTH        = 480.0
  private WINDOW_HEIGHT       =  80.0
  private READINESS_TIMEOUT   = 5.seconds
  private PASTEBOARD_SENTINEL = "asset-pipeline tracking copy sentinel"
  private INK_COLOR           = UI::Color.new(r: 0.0, g: 0.0, b: 0.0)

  private MONOSPACED_FONT   = UI::Font.new(family: "monospace", size: FONT_SIZE)
  private PROPORTIONAL_FONT = UI::Font.new(family: "Helvetica", size: FONT_SIZE)
  private SYSTEM_FONT       = UI::Font.new(size: FONT_SIZE, weight: :semibold)

  # What one capture measured, in 2x pixels (ink) and points (layout).
  private record TrackingMeasurement,
    ink_width_pixels : Int32,
    list_of_ink_line_heights : Array(Int32),
    fitting_width : Float64,
    fitting_height : Float64

  private def tracked_label(text : String, font : UI::Font, tracking : Float64) : UI::Label
    label = UI::Label.new(text)
    label.font = font
    label.text_color = INK_COLOR
    label.tracking = tracking
    label
  end

  # Runs of consecutive rows holding ink, top to bottom: one per text line.
  private def ink_line_heights(list_of_ink_rows : Array(Bool)) : Array(Int32)
    list_of_heights = [] of Int32
    run = 0
    list_of_ink_rows.each do |row_has_ink|
      if row_has_ink
        run += 1
      elsif run > 0
        list_of_heights << run
        run = 0
      end
    end
    list_of_heights << run if run > 0
    list_of_heights
  end

  private def measure_ink(pixels : Bytes, width : Int32, height : Int32) : {Int32, Array(Int32)}
    leftmost = width
    rightmost = -1
    list_of_ink_rows = Array(Bool).new(height, false)
    height.times do |row|
      width.times do |column|
        next if pixels[(row * width + column) * 4 + 3] < INK_ALPHA_THRESHOLD
        leftmost = column if column < leftmost
        rightmost = column if column > rightmost
        list_of_ink_rows[row] = true
      end
    end
    raise "The capture holds no ink (#{width}x#{height})" if rightmost < 0

    {rightmost - leftmost + 1, ink_line_heights(list_of_ink_rows)}
  end

  private def with_tracking_window(view : UI::View, width : Float64 = WINDOW_WIDTH, height : Float64 = WINDOW_HEIGHT, & : Void* ->) : Nil
    native = UI::AppKit::Renderer.new.render(view)
    window = LabelTrackingSpecBridge.ap_spec_tracking_window_new(native.handle.ptr!, width, height)
    raise "The offscreen tracking window could not be created" if window.null?
    begin
      yield window
      LabelTrackingSpecBridge.ap_spec_tracking_application_is_active.should eq(0)
      LabelTrackingSpecBridge.ap_spec_tracking_window_is_key(window).should eq(0)
    ensure
      LabelTrackingSpecBridge.ap_spec_tracking_window_close(window)
      native.teardown!
    end
  end

  private def measure(view : UI::View, width : Float64 = WINDOW_WIDTH, height : Float64 = WINDOW_HEIGHT) : TrackingMeasurement
    measurement : TrackingMeasurement? = nil
    with_tracking_window(view, width, height) do |window|
      pixels = Bytes.new(CAPTURE_CAPACITY)
      size = StaticArray(Int32, 2).new(0)
      captured = LabelTrackingSpecBridge.ap_spec_tracking_capture(window, CAPTURE_SCALE, pixels.to_unsafe, CAPTURE_CAPACITY, size.to_unsafe)
      raise "The Label could not be captured" if captured == 0

      ink_width, list_of_line_heights = measure_ink(pixels, size[0], size[1])
      fitting_width = 0.0
      fitting_height = 0.0
      LabelTrackingSpecBridge.ap_spec_tracking_fitting_size(window, pointerof(fitting_width), pointerof(fitting_height))
      measurement = TrackingMeasurement.new(ink_width, list_of_line_heights, fitting_width, fitting_height)
    end
    measurement || raise("The Label was not measured")
  end

  # Renders `text` untracked and tracked in `font` and checks the pixel ink
  # width grew by (glyph count - 1) x tracking and the layout width by glyph
  # count x tracking.
  private def assert_tracking_widens(text : String, font : UI::Font) : Nil
    untracked = measure(tracked_label(text, font, 0.0))
    tracked = measure(tracked_label(text, font, TRACKING_POINTS))

    glyph_count = text.size
    ink_growth = tracked.ink_width_pixels - untracked.ink_width_pixels
    expected_ink_growth = (glyph_count - 1) * TRACKING_POINTS * CAPTURE_SCALE
    ink_report = "#{font.family} #{font.size}pt #{text.inspect}: ink #{untracked.ink_width_pixels}px -> " \
                 "#{tracked.ink_width_pixels}px (+#{ink_growth}px, expected +#{expected_ink_growth.round(2)}px)"
    (ink_growth - expected_ink_growth).abs.should be <= PIXEL_TOLERANCE, ink_report

    layout_growth = tracked.fitting_width - untracked.fitting_width
    expected_layout_growth = glyph_count * TRACKING_POINTS
    layout_report = "#{font.family}: fitting width #{untracked.fitting_width}pt -> #{tracked.fitting_width}pt " \
                    "(+#{layout_growth.round(2)}pt, expected +#{expected_layout_growth.round(2)}pt)"
    (layout_growth - expected_layout_growth).abs.should be <= PIXEL_TOLERANCE / CAPTURE_SCALE, layout_report

    tracked.list_of_ink_line_heights.size.should eq(1)
  end

  private def find_static_texts(element : UI::AXTest::Element, depth : Int32 = 0) : Array(UI::AXTest::Element)
    return [] of UI::AXTest::Element if depth > 16

    list_of_static_texts = [] of UI::AXTest::Element
    element.children.each do |child|
      list_of_static_texts << child if child.role == "AXStaticText"
      list_of_static_texts.concat(find_static_texts(child, depth + 1))
    end
    list_of_static_texts
  end

  private def wait_for_ax_label(test_id : String) : UI::AXTest::Element
    app = UI::AXTest::App.connect(Process.pid.to_i32)
    deadline = Time.instant + READINESS_TIMEOUT
    loop do
      LabelTrackingCopyBridge.ap_spec_pump_label_run_loop
      if label = app.find_by_id(test_id)
        return label if label.frame
      end
      raise "AXTest did not expose #{test_id.inspect} within #{READINESS_TIMEOUT}" if Time.instant >= deadline
    end
  end

  private def center_of(element : UI::AXTest::Element) : {Float64, Float64}
    frame = element.frame || raise("The Label has no accessibility frame")
    {frame[:x] + frame[:width] / 2, frame[:y] + frame[:height] / 2}
  end

  private def pasteboard_text : String?
    text_ptr = LabelTrackingCopyBridge.ap_spec_pasteboard_copy_string
    return nil if text_ptr.null?

    text = String.new(text_ptr)
    LibC.free(text_ptr.as(Void*))
    text
  end

  describe "UI::Label tracking on macOS" do
    it "widens a monospaced 11 pt label by the tracking between every glyph" do
      assert_tracking_widens(TRACKED_TEXT, MONOSPACED_FONT)
    end

    it "widens a proportional custom-family label the same way" do
      # The custom family really rendered, proportionally: ten narrow capitals
      # take far less ink than in the monospaced font.
      narrow_capitals = "IIIIIIIIII"
      proportional = measure(tracked_label(narrow_capitals, PROPORTIONAL_FONT, 0.0))
      monospaced = measure(tracked_label(narrow_capitals, MONOSPACED_FONT, 0.0))
      proportional.ink_width_pixels.should be < monospaced.ink_width_pixels * 0.7

      assert_tracking_widens(TRACKED_TEXT, PROPORTIONAL_FONT)
    end

    it "widens a system-font label with an explicit weight the same way" do
      assert_tracking_widens(TRACKED_TEXT, SYSTEM_FONT)
    end

    it "leaves an untracked label exactly as wide as before" do
      baseline = measure(tracked_label(TRACKED_TEXT, MONOSPACED_FONT, 0.0))
      label = UI::Label.new(TRACKED_TEXT)
      label.font = MONOSPACED_FONT
      label.text_color = INK_COLOR
      measure(label).ink_width_pixels.should eq(baseline.ink_width_pixels)
    end

    it "exposes one static text whose value is the whole string" do
      label = tracked_label(TRACKED_TEXT, MONOSPACED_FONT, TRACKING_POINTS)
      label.test_id = "tracked-label"
      with_tracking_window(label) do |_window|
        element = wait_for_ax_label("tracked-label")
        element.role.should eq("AXStaticText")
        element.value.should eq(TRACKED_TEXT)
        element.children.should be_empty

        app = UI::AXTest::App.connect(Process.pid.to_i32)
        list_of_values = find_static_texts(app.root).compact_map(&.value)
        list_of_values.should contain(TRACKED_TEXT)
        list_of_values.none? { |value| value.size == 1 }.should be_true
      end
    end

    it "copies the plain string from a selectable tracked label" do
      label = tracked_label(TRACKED_TEXT, MONOSPACED_FONT, TRACKING_POINTS)
      label.selectable = true
      label.test_id = "tracked-selectable-label"
      pasteboard_snapshot = LabelTrackingCopyBridge.ap_spec_pasteboard_snapshot
      begin
        with_tracking_window(label) do |window|
          LabelTrackingCopyBridge.ap_spec_pasteboard_write_string(PASTEBOARD_SENTINEL)
          element = wait_for_ax_label("tracked-selectable-label")
          x, y = center_of(element)

          deadline = Time.instant + READINESS_TIMEOUT
          until LabelTrackingCopyBridge.ap_spec_ax_point_hits_selectable_text(window, x, y) == 1
            raise "The selectable text view never appeared under the Label" if Time.instant >= deadline
            LabelTrackingCopyBridge.ap_spec_pump_label_run_loop
          end

          LabelTrackingCopyBridge.ap_spec_triple_click_at_ax_point(window, x, y).should eq(1)
          LabelTrackingCopyBridge.ap_spec_pump_label_run_loop
          element.selected_text.should eq(TRACKED_TEXT)
          LabelTrackingCopyBridge.ap_spec_copy_from_first_responder(window).should eq(1)
          pasteboard_text.should eq(TRACKED_TEXT)
        end
      ensure
        LabelTrackingCopyBridge.ap_spec_pasteboard_restore(pasteboard_snapshot)
      end
    end

    it "wraps a tracked label that no longer fits its width" do
      text = "#{TRACKED_TEXT} #{TRACKED_TEXT}"
      untracked = measure(tracked_label(text, MONOSPACED_FONT, 0.0))
      untracked.list_of_ink_line_heights.size.should eq(1)

      # Wide enough for the untracked string, too narrow once it is tracked.
      wrap_width = (untracked.fitting_width + 4.0).ceil
      tracked = tracked_label(text, MONOSPACED_FONT, TRACKING_POINTS)
      tracked.preferred_max_layout_width = wrap_width
      wrapped = measure(tracked, wrap_width, WINDOW_HEIGHT)

      wrapped.list_of_ink_line_heights.size.should eq(2)
      (wrapped.ink_width_pixels / CAPTURE_SCALE).should be <= wrap_width
      wrapped.fitting_height.should be > untracked.fitting_height * 1.8
    end
  end
{% end %}
