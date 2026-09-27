require "spec"
require "../../../src/ui"

{% if flag?(:macos) %}
  # Measures real Auto Layout frames of rendered AppKit stacks: a wrapped
  # Label must grow its HStack row so the next row never overlaps it, and a
  # VStack column given a width must hold that width inside an HStack row.
  # Every number comes from the laid-out native views, never from the
  # properties the spec set.
  lib LayoutMeasurementSpecBridge
    fun ap_spec_layout_window_new(root : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_layout_frame_from_top(window : Void*, root : Void*, view : Void*, out_rect : Float64*) : Int32
    fun ap_spec_layout_fitting_size(view : Void*, out_size : Float64*) : Void
    fun ap_spec_layout_ink_rows(window : Void*, view : Void*, out_rows : UInt8*, capacity : Int32, out_pixels_per_point : Float64*) : Int32
    fun ap_spec_layout_application_is_active : Int32
    fun ap_spec_layout_window_close(window : Void*) : Void
  end

  # A laid-out frame in points, with `top` measured down from the root.
  private record MeasuredFrame, x : Float64, top : Float64, width : Float64, height : Float64 do
    def bottom : Float64
      top + height
    end

    def trailing : Float64
      x + width
    end

    def to_s(io : IO) : Nil
      io << "{x: " << x.round(2) << ", top: " << top.round(2) << ", w: " << width.round(2) << ", h: " << height.round(2) << '}'
    end
  end

  # One rendered tree hosted in an offscreen window.
  private class HostedLayout
    getter native : UI::NativeView
    getter window : Void*

    def initialize(view : UI::View, width : Float64)
      @native = UI::AppKit::Renderer.new.render(view)
      @window = LayoutMeasurementSpecBridge.ap_spec_layout_window_new(@native.handle.ptr!, width, 800.0)
    end

    # The native view reached by child indexes from the root.
    def node(*list_of_indexes : Int32) : UI::NativeView
      current = native
      list_of_indexes.each { |index| current = current.children[index] }
      current
    end

    def frame(node : UI::NativeView) : MeasuredFrame
      rect = StaticArray(Float64, 4).new(0.0)
      found = LayoutMeasurementSpecBridge.ap_spec_layout_frame_from_top(window, native.handle.ptr!, node.handle.ptr!, rect.to_unsafe)
      raise "The measured view is not in the capture window" if found == 0
      MeasuredFrame.new(rect[0], rect[1], rect[2], rect[3])
    end

    def fitting_height(node : UI::NativeView) : Float64
      size = StaticArray(Float64, 2).new(0.0)
      LayoutMeasurementSpecBridge.ap_spec_layout_fitting_size(node.handle.ptr!, size.to_unsafe)
      size[1]
    end

    # Tops of each run of inked rows (one per text line), in points.
    def list_of_line_tops(node : UI::NativeView) : Array(Float64)
      rows = Bytes.new(8192)
      pixels_per_point = 0.0
      count = LayoutMeasurementSpecBridge.ap_spec_layout_ink_rows(window, node.handle.ptr!, rows.to_unsafe, rows.size, pointerof(pixels_per_point))
      raise "The label could not be drawn" if count == 0
      list_of_tops = [] of Float64
      previous_inked = false
      count.times do |row|
        inked = rows[row] == 1
        list_of_tops << row / pixels_per_point if inked && !previous_inked
        previous_inked = inked
      end
      list_of_tops
    end

    def close : Nil
      LayoutMeasurementSpecBridge.ap_spec_layout_window_close(window)
      native.teardown!
    end
  end

  private def with_hosted_layout(view : UI::View, width : Float64, & : HostedLayout ->) : Nil
    hosted = HostedLayout.new(view, width)
    begin
      yield hosted
    ensure
      hosted.close
    end
    LayoutMeasurementSpecBridge.ap_spec_layout_application_is_active.should eq(0)
  end

  # Every word is the same width, so each wrapped line holds the same glyphs.
  private WRAPPED_COPY = (["HHHH"] * 30).join(" ")

  private def caption(text : String) : UI::Label
    label = UI::Label.new(text)
    label.font = UI::Font.new(size: 12.0)
    label
  end

  # Average distance between consecutive line tops.
  private def line_pitch(list_of_line_tops : Array(Float64)) : Float64
    (list_of_line_tops.last - list_of_line_tops.first) / (list_of_line_tops.size - 1)
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

  # Measures the first row's wrapped label, the row, and the row below it.
  private def measure_two_row_list(label : UI::Label, width : Float64, & : MeasuredFrame, MeasuredFrame, MeasuredFrame, Array(Float64) ->) : Nil
    with_hosted_layout(two_row_list(label), width) do |hosted|
      label_node = hosted.node(0, 1)
      yield hosted.frame(label_node), hosted.frame(hosted.node(0)), hosted.frame(hosted.node(1)), hosted.list_of_line_tops(label_node)
    end
  end

  describe "Wrapped Label height inside an HStack row on macOS" do
    it "grows the row to the wrapped line count so the next row never overlaps" do
      measure_two_row_list(caption(WRAPPED_COPY), 320.0) do |label_frame, row_frame, next_frame, list_of_line_tops|
        report = "label #{label_frame}, row #{row_frame}, next #{next_frame}, line tops #{list_of_line_tops.map(&.round(2))}"
        list_of_line_tops.size.should be >= 3, report
        pitch = line_pitch(list_of_line_tops)
        # The short time label keeps its width; only the long label compresses.
        label_frame.x.should be > 20.0, report
        label_frame.trailing.should be <= 320.5, report
        row_frame.height.should be >= list_of_line_tops.size * pitch - 1.0, report
        next_frame.top.should be >= label_frame.bottom - 0.5, report
        next_frame.top.should be >= row_frame.bottom - 0.5, report
      end
    end

    it "grows the row for a wrapped fill_horizontal label" do
      label = caption(WRAPPED_COPY)
      label.fill_horizontal = true
      measure_two_row_list(label, 320.0) do |label_frame, row_frame, next_frame, list_of_line_tops|
        report = "label #{label_frame}, row #{row_frame}, next #{next_frame}, line tops #{list_of_line_tops.map(&.round(2))}"
        list_of_line_tops.size.should be >= 3, report
        label_frame.x.should be > 20.0, report
        row_frame.height.should be >= list_of_line_tops.size * line_pitch(list_of_line_tops) - 1.0, report
        next_frame.top.should be >= label_frame.bottom - 0.5, report
        next_frame.top.should be >= row_frame.bottom - 0.5, report
      end
    end

    it "keeps the row a single line when the text fits" do
      measure_two_row_list(caption("Saved"), 320.0) do |label_frame, row_frame, next_frame, list_of_line_tops|
        report = "label #{label_frame}, row #{row_frame}, next #{next_frame}"
        list_of_line_tops.size.should eq(1), report
        row_frame.height.should be < 20.0, report
      end
    end

    it "stops at number_of_lines" do
      label = caption(WRAPPED_COPY)
      label.number_of_lines = 2
      measure_two_row_list(label, 320.0) do |label_frame, row_frame, next_frame, list_of_line_tops|
        report = "label #{label_frame}, row #{row_frame}, next #{next_frame}, line tops #{list_of_line_tops.map(&.round(2))}"
        list_of_line_tops.size.should eq(2), report
        next_frame.top.should be >= label_frame.bottom - 0.5, report
      end
    end

    it "spaces wrapped lines at line_height, measured from the drawn glyphs" do
      label = caption(WRAPPED_COPY)
      label.line_height = 16.0
      measure_two_row_list(label, 320.0) do |label_frame, row_frame, next_frame, list_of_line_tops|
        report = "label #{label_frame}, row #{row_frame}, next #{next_frame}, line tops #{list_of_line_tops.map(&.round(2))}"
        list_of_line_tops.size.should be >= 3, report
        line_pitch(list_of_line_tops).should be_close(16.0, 0.5), report
        row_frame.height.should be >= (list_of_line_tops.size - 1) * 16.0 + 12.0, report
        next_frame.top.should be >= label_frame.bottom - 0.5, report
      end
    end
  end

  describe "VStack width inside an HStack row on macOS" do
    [{"an exact width (minimum_width == maximum_width)", true}, {"maximum_width alone", false}].each do |description, sets_minimum|
      it "starts the next column at the VStack width plus spacing for #{description}" do
        row = UI::HStack.new(spacing: 12.0)
        time_column = UI::VStack.new(spacing: 2.0)
        time_column.minimum_width = 160.0 if sets_minimum
        time_column.maximum_width = 160.0
        time_column << caption("Tuesday, September 27, 2026 at 10:42:07 in the morning")
        event_column = UI::VStack.new(spacing: 2.0)
        event_column << caption(WRAPPED_COPY)
        row << time_column
        row << event_column

        with_hosted_layout(row, 600.0) do |hosted|
          time_frame = hosted.frame(hosted.node(0))
          event_frame = hosted.frame(hosted.node(1))
          report = "time #{time_frame}, event #{event_frame}"
          time_frame.width.should be_close(160.0, 0.5), report
          event_frame.x.should be_close(172.0, 0.5), report
        end
      end
    end
  end
{% end %}
