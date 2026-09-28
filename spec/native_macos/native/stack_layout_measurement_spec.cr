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
    fun ap_spec_layout_ink_span(window : Void*, view : Void*, out_span : Float64*) : Int32
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

    # Leading and trailing edges of the drawn glyphs, in points from the
    # root's leading edge.
    def ink_span(node : UI::NativeView) : Tuple(Float64, Float64)
      span = StaticArray(Float64, 2).new(0.0)
      found = LayoutMeasurementSpecBridge.ap_spec_layout_ink_span(window, node.handle.ptr!, span.to_unsafe)
      raise "The label drew no ink" if found == 0
      origin = frame(node).x
      {origin + span[0], origin + span[1]}
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

  describe "Fixed-width timestamp cell inside an HStack row on macOS" do
    # A padded 160 pt cell whose monospace timestamp Label is itself pinned to
    # 160 and fill_horizontal: neither the child's fill nor the Label's
    # hosting view may widen the cell.
    [600.0, 780.0].each do |window_width|
      it "starts the event column at 160 plus spacing in a #{window_width.to_i} pt row" do
        timestamp = UI::Label.new("10:42:07.123")
        timestamp.font = UI::Font.new(size: 12.0, family: "monospace")
        timestamp.minimum_width = 160.0
        timestamp.maximum_width = 160.0
        timestamp.fill_horizontal = true
        cell = UI::VStack.new(spacing: 0.0, alignment: UI::Alignment::Leading)
        cell.minimum_width = 160.0
        cell.maximum_width = 160.0
        cell.padding = UI::EdgeInsets.new(top: 12.0)
        cell << timestamp
        event_column = UI::VStack.new(spacing: 2.0, alignment: UI::Alignment::Leading)
        event_column << caption("Build finished")
        event_column << caption(WRAPPED_COPY)
        row = UI::HStack.new(spacing: 12.0)
        row << cell
        row << event_column

        with_hosted_layout(row, window_width) do |hosted|
          cell_frame = hosted.frame(hosted.node(0))
          event_frame = hosted.frame(hosted.node(1))
          title_frame = hosted.frame(hosted.node(1, 0))
          report = "cell #{cell_frame}, event #{event_frame}, title #{title_frame}"
          cell_frame.width.should be_close(160.0, 0.5), report
          event_frame.x.should be_close(172.0, 0.5), report
          title_frame.x.should be_close(172.0, 0.5), report
        end
      end
    end
  end

  # A label that hugs its text: no wider than its glyphs plus side bearings,
  # and the glyphs start at the label's leading edge.
  private def expect_label_hugs_text(hosted : HostedLayout, node : UI::NativeView, report : String) : Nil
    label_frame = hosted.frame(node)
    ink_leading, ink_trailing = hosted.ink_span(node)
    detail = "#{report}; label #{label_frame}, ink #{ink_leading.round(2)}..#{ink_trailing.round(2)}"
    label_frame.width.should be <= (ink_trailing - ink_leading) + 6.0, detail
    (ink_leading - label_frame.x).should be <= 2.5, detail
  end

  # The glyphs start at the label's leading edge, however wide the label is.
  private def expect_text_at_leading_edge(hosted : HostedLayout, node : UI::NativeView, leading_edge : Float64, report : String) : Nil
    ink_leading, ink_trailing = hosted.ink_span(node)
    detail = "#{report}; label #{hosted.frame(node)}, ink #{ink_leading.round(2)}..#{ink_trailing.round(2)}"
    (ink_leading - leading_edge).should be >= -0.5, detail
    (ink_leading - leading_edge).should be <= 2.5, detail
  end

  # A padded 160 pt timestamp cell, the leading column of a log row.
  private def timestamp_cell : UI::VStack
    timestamp = caption("10:42:07")
    timestamp.minimum_width = 160.0
    timestamp.maximum_width = 160.0
    timestamp.fill_horizontal = true
    cell = UI::VStack.new(spacing: 0.0, alignment: UI::Alignment::Leading)
    cell.minimum_width = 160.0
    cell.maximum_width = 160.0
    cell << timestamp
    cell
  end

  # A full-width row inside a leading page column.
  private def page_with_row(row : UI::HStack) : UI::VStack
    row.fill_horizontal = true
    page = UI::VStack.new(spacing: 0.0, alignment: UI::Alignment::Leading)
    page << row
    page
  end

  describe "Label width beside a fixed column in an HStack row on macOS" do
    it "keeps short labels at their text width, so the next label follows the first" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      row << timestamp_cell
      row << caption("stdout")
      row << caption("Build finished")

      with_hosted_layout(page_with_row(row), 600.0) do |hosted|
        stream_node = hosted.node(0, 1)
        message_node = hosted.node(0, 2)
        stream_frame = hosted.frame(stream_node)
        message_frame = hosted.frame(message_node)
        report = "stream #{stream_frame}, message #{message_frame}"
        stream_frame.x.should be_close(172.0, 0.5), report
        expect_label_hugs_text(hosted, stream_node, report)
        message_frame.x.should be_close(stream_frame.trailing + 12.0, 0.5), report
        expect_label_hugs_text(hosted, message_node, report)
      end
    end

    it "holds a trailing-aligned stream column beside a filling, wrapped output line" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      stream = caption("stdout")
      stream.minimum_width = 48.0
      stream.maximum_width = 48.0
      stream.text_alignment = UI::Alignment::Trailing
      output = caption(WRAPPED_COPY)
      output.fill_horizontal = true
      row << stream
      row << output

      with_hosted_layout(page_with_row(row), 420.0) do |hosted|
        stream_node = hosted.node(0, 0)
        output_node = hosted.node(0, 1)
        stream_frame = hosted.frame(stream_node)
        output_frame = hosted.frame(output_node)
        row_frame = hosted.frame(hosted.node(0))
        _, stream_ink_trailing = hosted.ink_span(stream_node)
        list_of_line_tops = hosted.list_of_line_tops(output_node)
        report = "stream #{stream_frame}, stream ink ends #{stream_ink_trailing.round(2)}, output #{output_frame}, row #{row_frame}, output lines #{list_of_line_tops.size}"
        stream_frame.x.should be_close(0.0, 0.5), report
        stream_frame.width.should be_close(48.0, 0.5), report
        stream_ink_trailing.should be <= stream_frame.trailing + 0.5, report
        stream_ink_trailing.should be >= stream_frame.trailing - 2.5, report
        output_frame.x.should be_close(60.0, 0.5), report
        expect_text_at_leading_edge(hosted, output_node, 60.0, report)
        list_of_line_tops.size.should be >= 2, report
        row_frame.height.should be >= list_of_line_tops.size * line_pitch(list_of_line_tops) - 1.0, report
      end
    end

    it "starts a preferred-width detail at the leading edge of a filled event column" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      row << timestamp_cell
      title = caption("Build finished")
      title.fill_horizontal = true
      detail = caption("exit 0")
      detail.fill_horizontal = true
      detail.number_of_lines = 1
      detail.preferred_max_layout_width = 240.0
      event_column = UI::VStack.new(4.0, UI::Alignment::Fill)
      event_column.fill_horizontal = true
      event_column << title
      event_column << detail
      row << event_column

      with_hosted_layout(page_with_row(row), 600.0) do |hosted|
        column_frame = hosted.frame(hosted.node(0, 1))
        report = "event column #{column_frame}"
        column_frame.x.should be_close(172.0, 0.5), report
        expect_text_at_leading_edge(hosted, hosted.node(0, 1, 0), column_frame.x, report)
        expect_text_at_leading_edge(hosted, hosted.node(0, 1, 1), column_frame.x, report)
      end
    end
  end

  # Two cards side by side, each a padded 200 pt column: a name, a count, and
  # a wrapped next step with a preferred width, each with a minimum height.
  private def provider_card(name : String) : UI::VStack
    card = UI::VStack.new(spacing: 6.0, alignment: UI::Alignment::Leading)
    card.padding = UI::EdgeInsets.new(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
    card.minimum_width = 200.0
    card.maximum_width = 200.0
    title = UI::Label.new(name)
    title.font = UI::Font.new(size: 13.0, weight: :semibold)
    title.minimum_height = 18.0
    card << title
    count = UI::Label.new("1 active profile")
    count.font = UI::Font.new(size: 11.0)
    count.minimum_height = 16.0
    card << count
    next_step = UI::Label.new(WRAPPED_COPY)
    next_step.font = UI::Font.new(size: 11.0)
    next_step.minimum_height = 16.0
    next_step.number_of_lines = 0
    next_step.preferred_max_layout_width = 184.0
    card << next_step
    card
  end

  describe "Labels in a fixed-width card VStack on macOS" do
    it "gives each label its line height, stacked without overlap and hugging its text" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      row << provider_card("Provider one")
      row << provider_card("Provider two")

      with_hosted_layout(page_with_row(row), 600.0) do |hosted|
        2.times do |card_index|
          card_frame = hosted.frame(hosted.node(0, card_index))
          name_node = hosted.node(0, card_index, 0)
          count_node = hosted.node(0, card_index, 1)
          step_node = hosted.node(0, card_index, 2)
          name_frame = hosted.frame(name_node)
          count_frame = hosted.frame(count_node)
          step_frame = hosted.frame(step_node)
          report = "card #{card_frame}, name #{name_frame}, count #{count_frame}, step #{step_frame}"
          card_frame.width.should be_close(200.0, 0.5), report
          name_frame.height.should be >= 17.5, report
          count_frame.height.should be >= 15.5, report
          count_frame.top.should be >= name_frame.bottom + 5.5, report
          step_frame.top.should be >= count_frame.bottom + 5.5, report
          name_frame.x.should be_close(card_frame.x + 8.0, 0.5), report
          count_frame.x.should be_close(card_frame.x + 8.0, 0.5), report
          expect_label_hugs_text(hosted, name_node, report)
          expect_label_hugs_text(hosted, count_node, report)
          hosted.list_of_line_tops(step_node).size.should be >= 3, report
          expect_text_at_leading_edge(hosted, step_node, card_frame.x + 8.0, report)
          card_frame.bottom.should be >= step_frame.bottom + 7.5, report
        end
      end
    end
  end

  describe "Label and value in a form row on macOS" do
    # A padded row: a label pinned to a 152 pt column, then a filling value.
    it "starts the label text and the value at their column edges" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Center)
      row.padding = UI::EdgeInsets.new(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0)
      key = caption("Source")
      key.minimum_width = 152.0
      key.maximum_width = 152.0
      value = caption("Snapshot")
      value.fill_horizontal = true
      row << key
      row << value

      with_hosted_layout(page_with_row(row), 600.0) do |hosted|
        key_frame = hosted.frame(hosted.node(0, 0))
        value_frame = hosted.frame(hosted.node(0, 1))
        report = "key #{key_frame}, value #{value_frame}"
        key_frame.x.should be_close(16.0, 0.5), report
        key_frame.width.should be_close(152.0, 0.5), report
        expect_text_at_leading_edge(hosted, hosted.node(0, 0), 16.0, report)
        value_frame.x.should be_close(180.0, 0.5), report
        expect_text_at_leading_edge(hosted, hosted.node(0, 1), 180.0, report)
      end
    end

    it "keeps both labels at their text width around a spacer" do
      row = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Center)
      row.padding = UI::EdgeInsets.new(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0)
      row << caption("Source")
      row << UI::Spacer.new
      row << caption("Snapshot")

      with_hosted_layout(page_with_row(row), 600.0) do |hosted|
        key_node = hosted.node(0, 0)
        value_node = hosted.node(0, 2)
        key_frame = hosted.frame(key_node)
        value_frame = hosted.frame(value_node)
        report = "key #{key_frame}, value #{value_frame}"
        key_frame.x.should be_close(16.0, 0.5), report
        expect_label_hugs_text(hosted, key_node, report)
        value_frame.trailing.should be_close(584.0, 0.5), report
        expect_label_hugs_text(hosted, value_node, report)
      end
    end
  end

  describe "Labels in fixed-width cards inside a Form section on macOS" do
    it "keeps each card's labels stacked at their line heights" do
      strip = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      strip.fill_horizontal = true
      strip.minimum_width = 520.0
      strip << provider_card("Provider one")
      strip << provider_card("Provider two")
      form = UI::Form.new
      form.add_section("Readiness").fields << UI::Form::Field.new(content: strip)
      page = UI::VStack.new(spacing: 0.0, alignment: UI::Alignment::Leading)
      page << form

      with_hosted_layout(page, 640.0) do |hosted|
        2.times do |card_index|
          card_frame = hosted.frame(hosted.node(0, 0, card_index))
          list_of_frames = (0..2).map { |label_index| hosted.frame(hosted.node(0, 0, card_index, label_index)) }
          report = "card #{card_frame}, labels #{list_of_frames.join(", ")}"
          list_of_frames[0].height.should be >= 17.5, report
          list_of_frames[1].height.should be >= 15.5, report
          list_of_frames[1].top.should be >= list_of_frames[0].bottom + 5.5, report
          list_of_frames[2].top.should be >= list_of_frames[1].bottom + 5.5, report
          hosted.list_of_line_tops(hosted.node(0, 0, card_index, 2)).size.should be >= 3, report
          card_frame.bottom.should be >= list_of_frames[2].bottom + 7.5, report
        end
      end
    end
  end
{% end %}
