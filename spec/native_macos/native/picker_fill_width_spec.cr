require "spec"
require "../../../src/ui"

{% if flag?(:macos) %}
  # Measures the laid-out width of a rendered menu Picker: a fill_horizontal
  # picker spans its column, and a plain one keeps hugging its widest option.
  lib PickerFillWidthSpecBridge
    fun ap_spec_layout_window_new(root : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_layout_frame_from_top(window : Void*, root : Void*, view : Void*, out_rect : Float64*) : Int32
    fun ap_spec_layout_window_close(window : Void*) : Void
  end

  private def measured_picker_width(is_fill_horizontal : Bool, column_width : Float64) : Float64
    picker = UI::Picker.new(["Claude Code", "Codex"], 0)
    picker.style = UI::PickerStyle::Menu
    picker.fill_horizontal = is_fill_horizontal
    column = UI::VStack.new(0.0, UI::Alignment::Fill)
    column.minimum_width = column_width
    column.maximum_width = column_width
    column << picker

    native = UI::AppKit::Renderer.new.render(column)
    window = PickerFillWidthSpecBridge.ap_spec_layout_window_new(native.handle.ptr!, column_width, 200.0)
    begin
      rect = StaticArray(Float64, 4).new(0.0)
      found = PickerFillWidthSpecBridge.ap_spec_layout_frame_from_top(
        window, native.handle.ptr!, native.children[0].handle.ptr!, rect.to_unsafe,
      )
      raise "The picker is not in the capture window" if found == 0
      rect[2]
    ensure
      PickerFillWidthSpecBridge.ap_spec_layout_window_close(window)
      native.teardown!
    end
  end

  describe "UI::Picker fill_horizontal on macOS" do
    it "spans its column when fill_horizontal" do
      measured_picker_width(true, 480.0).should be_close(480.0, 0.5)
    end

    it "keeps hugging its widest option otherwise" do
      measured_picker_width(false, 480.0).should be < 300.0
    end
  end
{% end %}
