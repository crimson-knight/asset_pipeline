require "spec"
require "../../../src/ui"
require "../../../src/ui/ax_test"

{% if flag?(:macos) %}
  # Proves `UI::Label#tracking` and `UI::Label#line_height` work together on a
  # Label that wraps inside an HStack row: the row grows by the line height per
  # wrapped line, each drawn line is wider by the tracking between its glyphs,
  # and VoiceOver still reads one static text. Every number comes from the
  # laid-out native views and the pixels they draw.
  lib LabelTrackingWrapLayoutSpecBridge
    fun ap_spec_layout_window_new(root : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_layout_frame_from_top(window : Void*, root : Void*, view : Void*, out_rect : Float64*) : Int32
    fun ap_spec_layout_application_is_active : Int32
    fun ap_spec_layout_window_close(window : Void*) : Void
    fun ap_spec_tracking_capture(window : Void*, scale : Float64, out_rgba : UInt8*, capacity : Int64, out_size : Int32*) : Int32
    fun ap_spec_tracking_window_new(view : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_tracking_application_is_active : Int32
    fun ap_spec_tracking_window_is_key(window : Void*) : Int32
    fun ap_spec_tracking_window_close(window : Void*) : Void
    fun ap_spec_pump_label_run_loop : Void
  end

  private FONT_SIZE           = 12.0
  private TRACKING_POINTS     = FONT_SIZE * 0.11 # 0.11 em = 1.32 pt
  private LINE_HEIGHT         = 16.0
  private CAPTURE_SCALE       =  2.0
  private CAPTURE_CAPACITY    = 4_i64 * 2048 * 2048
  private INK_ALPHA_THRESHOLD =   128
  private PIXEL_TOLERANCE     =   1.0
  private ROW_WIDTH           = 180.0
  private WINDOW_HEIGHT       = 800.0
  private READINESS_TIMEOUT   = 5.seconds
  private INK_COLOR           = UI::Color.new(r: 0.0, g: 0.0, b: 0.0)

  # Four equal words, each too wide to share a line with the next at this row
  # width tracked or not, so every wrapped line holds exactly one word.
  private WRAP_WORD = "HHHHHHHHHH"
  private WRAP_COPY = ([WRAP_WORD] * 4).join(" ")

  # A laid-out frame in points, with `top` measured down from the root.
  private record MeasuredFrame, x : Float64, top : Float64, width : Float64, height : Float64 do
    def bottom : Float64
      top + height
    end

    def to_s(io : IO) : Nil
      io << "{x: " << x.round(2) << ", top: " << top.round(2) << ", w: " << width.round(2) << ", h: " << height.round(2) << '}'
    end
  end

  # One drawn text line: its first inked pixel row and its ink width, in pixels.
  private record InkLine, top_pixel : Int32, width_pixels : Int32

  # What one rendered two-row list measured.
  private record RowMeasurement,
    label_frame : MeasuredFrame,
    row_frame : MeasuredFrame,
    next_frame : MeasuredFrame,
    list_of_ink_lines : Array(InkLine) do
    def line_count : Int32
      list_of_ink_lines.size
    end

    # Average distance between consecutive line tops, in points.
    def line_pitch : Float64
      first = list_of_ink_lines.first.top_pixel
      last = list_of_ink_lines.last.top_pixel
      (last - first) / CAPTURE_SCALE / (line_count - 1)
    end

    def to_s(io : IO) : Nil
      io << "label " << label_frame << ", row " << row_frame << ", next " << next_frame
      io << ", ink lines " << list_of_ink_lines.map { |line| {line.top_pixel, line.width_pixels} }
    end
  end

  private def wrapped_label(tracking : Float64, text : String = WRAP_COPY) : UI::Label
    label = UI::Label.new(text)
    label.font = UI::Font.new(size: FONT_SIZE)
    label.text_color = INK_COLOR
    label.tracking = tracking
    label.line_height = LINE_HEIGHT
    label
  end

  private def caption(text : String) : UI::Label
    label = UI::Label.new(text)
    label.font = UI::Font.new(size: FONT_SIZE)
    label.text_color = INK_COLOR
    label
  end

  # A timeline row: a short time label, then `label`, above a second row.
  private def two_row_list(label : UI::Label) : UI::VStack
    list = UI::VStack.new(spacing: 0.0)
    list.alignment = UI::Alignment::Leading
    row = UI::HStack.new(spacing: 8.0)
    row.alignment = UI::Alignment::Top
    row << caption("10:42")
    row << label
    list << row
    list << caption("next row")
    list
  end

  private def frame_of(window : Void*, root : UI::NativeView, node : UI::NativeView) : MeasuredFrame
    rect = StaticArray(Float64, 4).new(0.0)
    found = LabelTrackingWrapLayoutSpecBridge.ap_spec_layout_frame_from_top(window, root.handle.ptr!, node.handle.ptr!, rect.to_unsafe)
    raise "The measured view is not in the capture window" if found == 0
    MeasuredFrame.new(rect[0], rect[1], rect[2], rect[3])
  end

  # Splits the ink inside `frame` into runs of inked rows (one per text line)
  # and measures each run from its leftmost to its rightmost inked column.
  private def ink_lines(pixels : Bytes, width : Int32, height : Int32, frame : MeasuredFrame) : Array(InkLine)
    first_column = (frame.x * CAPTURE_SCALE).floor.to_i.clamp(0, width)
    last_column = ((frame.x + frame.width) * CAPTURE_SCALE).ceil.to_i.clamp(0, width)
    first_row = (frame.top * CAPTURE_SCALE).floor.to_i.clamp(0, height)
    last_row = (frame.bottom * CAPTURE_SCALE).ceil.to_i.clamp(0, height)

    list_of_lines = [] of InkLine
    line_top = -1
    leftmost = width
    rightmost = -1
    (first_row...last_row).each do |row|
      row_left = width
      row_right = -1
      (first_column...last_column).each do |column|
        next if pixels[(row * width + column) * 4 + 3] < INK_ALPHA_THRESHOLD
        row_left = column if column < row_left
        row_right = column
      end

      if row_right >= 0
        line_top = row if line_top < 0
        leftmost = row_left if row_left < leftmost
        rightmost = row_right if row_right > rightmost
      elsif line_top >= 0
        list_of_lines << InkLine.new(line_top, rightmost - leftmost + 1)
        line_top = -1
        leftmost = width
        rightmost = -1
      end
    end
    list_of_lines << InkLine.new(line_top, rightmost - leftmost + 1) if line_top >= 0
    raise "The label drew no ink inside #{frame}" if list_of_lines.empty?
    list_of_lines
  end

  # Lays out the two-row list at ROW_WIDTH, then draws it at 2x and measures
  # the wrapped label's ink line by line.
  private def measure_row(label : UI::Label) : RowMeasurement
    native = UI::AppKit::Renderer.new.render(two_row_list(label))
    window = LabelTrackingWrapLayoutSpecBridge.ap_spec_layout_window_new(native.handle.ptr!, ROW_WIDTH, WINDOW_HEIGHT)
    begin
      row = native.children[0]
      label_node = row.children[1]
      label_frame = frame_of(window, native, label_node)
      row_frame = frame_of(window, native, row)
      next_frame = frame_of(window, native, native.children[1])

      pixels = Bytes.new(CAPTURE_CAPACITY)
      size = StaticArray(Int32, 2).new(0)
      captured = LabelTrackingWrapLayoutSpecBridge.ap_spec_tracking_capture(window, CAPTURE_SCALE, pixels.to_unsafe, CAPTURE_CAPACITY, size.to_unsafe)
      raise "The row could not be captured" if captured == 0

      RowMeasurement.new(label_frame, row_frame, next_frame, ink_lines(pixels, size[0], size[1], label_frame))
    ensure
      LabelTrackingWrapLayoutSpecBridge.ap_spec_layout_window_close(window)
      native.teardown!
    end
  ensure
    LabelTrackingWrapLayoutSpecBridge.ap_spec_layout_application_is_active.should eq(0)
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

  private def wait_for_ax_label(app : UI::AXTest::App, test_id : String) : UI::AXTest::Element
    deadline = Time.instant + READINESS_TIMEOUT
    loop do
      LabelTrackingWrapLayoutSpecBridge.ap_spec_pump_label_run_loop
      if label = app.find_by_id(test_id)
        return label if label.frame
      end
      raise "AXTest did not expose #{test_id.inspect} within #{READINESS_TIMEOUT}" if Time.instant >= deadline
    end
  end

  describe "UI::Label tracking and line_height together in an HStack row on macOS" do
    it "grows the row by the line height per wrapped line and widens each line by its tracking" do
      single_line = measure_row(wrapped_label(TRACKING_POINTS, WRAP_WORD))
      untracked = measure_row(wrapped_label(0.0))
      tracked = measure_row(wrapped_label(TRACKING_POINTS))
      report = "single line #{single_line}; untracked #{untracked}; tracked #{tracked}"

      # Both wrap to one word per line, so each line's glyph count is known.
      single_line.line_count.should eq(1), report
      tracked.line_count.should eq(4), report
      untracked.line_count.should eq(4), report

      # Line height: consecutive drawn lines are 16 pt apart, and the row grows
      # past a one-line row by 16 pt for every wrapped line after the first.
      # SwiftUI adds line spacing between lines only, so the first line keeps
      # its natural height.
      tracked.line_pitch.should be_close(LINE_HEIGHT, 0.5), report
      row_growth = tracked.row_frame.height - single_line.row_frame.height
      row_growth.should be_close((tracked.line_count - 1) * LINE_HEIGHT, 0.5), report
      tracked.row_frame.height.should be >= tracked.label_frame.height - 0.5, report
      tracked.next_frame.top.should be >= tracked.row_frame.bottom - 0.5, report
      tracked.next_frame.top.should be >= tracked.label_frame.bottom - 0.5, report
      tracked.row_frame.height.should be_close(untracked.row_frame.height, 0.5), report

      # Tracking: every drawn line is wider by (glyph count - 1) x tracking.
      expected_growth = (WRAP_WORD.size - 1) * TRACKING_POINTS * CAPTURE_SCALE
      tracked.list_of_ink_lines.zip(untracked.list_of_ink_lines).each do |tracked_line, untracked_line|
        growth = tracked_line.width_pixels - untracked_line.width_pixels
        (growth - expected_growth).abs.should be <= PIXEL_TOLERANCE,
          "line growth +#{growth}px, expected +#{expected_growth.round(2)}px; #{report}"
        # Wrapping keeps the tracking: a wrapped line inks like the word alone.
        (tracked_line.width_pixels - single_line.list_of_ink_lines.first.width_pixels).abs.should be <= PIXEL_TOLERANCE, report
      end

      # The row stays inside its width and the time label keeps its place.
      tracked.label_frame.x.should be > 20.0, report
      (tracked.label_frame.x + tracked.label_frame.width).should be <= ROW_WIDTH + 0.5, report
    end

    it "exposes the wrapped, tracked label as one static text" do
      label = wrapped_label(TRACKING_POINTS)
      label.test_id = "tracked-wrapped-label"
      native = UI::AppKit::Renderer.new.render(two_row_list(label))
      window = LabelTrackingWrapLayoutSpecBridge.ap_spec_tracking_window_new(native.handle.ptr!, ROW_WIDTH, 120.0)
      raise "The offscreen tracking window could not be created" if window.null?
      begin
        app = UI::AXTest::App.connect(Process.pid.to_i32)
        element = wait_for_ax_label(app, "tracked-wrapped-label")
        element.role.should eq("AXStaticText")
        element.value.should eq(WRAP_COPY)
        element.children.should be_empty

        list_of_values = find_static_texts(app.root).compact_map(&.value)
        list_of_values.count(WRAP_COPY).should eq(1)
        list_of_values.none? { |value| value == WRAP_WORD || value.size == 1 }.should be_true

        LabelTrackingWrapLayoutSpecBridge.ap_spec_tracking_application_is_active.should eq(0)
        LabelTrackingWrapLayoutSpecBridge.ap_spec_tracking_window_is_key(window).should eq(0)
      ensure
        LabelTrackingWrapLayoutSpecBridge.ap_spec_tracking_window_close(window)
        native.teardown!
      end
    end
  end
{% end %}
