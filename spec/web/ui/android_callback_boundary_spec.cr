require "../../../src/ui"
require "spec"

describe UI::Android::CallbackBoundary do
  it "contains every callback signature without unwinding across its export" do
    ids = [] of UInt64
    begin
      ids << UI::CallbackRegistry.register(-> { raise "private-void-data"; nil })
      ids << UI::CallbackRegistry.register_string(->(value : String) { raise value; nil })
      ids << UI::CallbackRegistry.register_bool(->(value : Bool) { raise "private-bool-data"; nil })
      ids << UI::CallbackRegistry.register_float(->(value : Float64) { raise "private-float-data"; nil })
      ids << UI::CallbackRegistry.register_int(->(value : Int32) { raise "private-int-data"; nil })
      text = "private\0雪 😀"
      crystal_android_host_callback_void(ids[0]).should eq(0)
      crystal_android_host_callback_string(ids[1], text.to_unsafe, text.bytesize).should eq(0)
      crystal_android_host_callback_bool(ids[2], 1).should eq(0)
      crystal_android_host_callback_float(ids[3], 2.5).should eq(0)
      crystal_android_host_callback_int(ids[4], 7).should eq(0)
    ensure
      UI::CallbackRegistry.unregister(ids)
    end
  end

  it "reports real success and preserves all value types including UTF-8/NUL" do
    seen = [] of String
    ids = [] of UInt64
    begin
      ids << UI::CallbackRegistry.register(-> { seen << "void"; nil })
      ids << UI::CallbackRegistry.register_string(->(value : String) { seen << value; nil })
      ids << UI::CallbackRegistry.register_bool(->(value : Bool) { seen << value.to_s; nil })
      ids << UI::CallbackRegistry.register_float(->(value : Float64) { seen << value.to_s; nil })
      ids << UI::CallbackRegistry.register_int(->(value : Int32) { seen << value.to_s; nil })
      text = "a\0雪 😀"
      crystal_android_host_callback_void(ids[0]).should eq(1)
      crystal_android_host_callback_string(ids[1], text.to_unsafe, text.bytesize).should eq(1)
      crystal_android_host_callback_bool(ids[2], 0).should eq(1)
      crystal_android_host_callback_float(ids[3], 2.5).should eq(1)
      crystal_android_host_callback_int(ids[4], 7).should eq(1)
      seen.should eq(["void", text, "false", "2.5", "7"])
    ensure
      UI::CallbackRegistry.unregister(ids)
    end
  end

  it "rejects invalid buffers, allows explicit empty strings and ignores stale IDs" do
    seen = [] of String
    id = UI::CallbackRegistry.register_string(->(value : String) { seen << value; nil })
    begin
      null = Pointer(UInt8).null
      crystal_android_host_callback_string(id, null, -1).should eq(0)
      crystal_android_host_callback_string(id, null, 1).should eq(0)
      seen.should be_empty
      crystal_android_host_callback_string(id, null, 0).should eq(1)
      seen.should eq([""])
    ensure
      UI::CallbackRegistry.unregister(id)
    end
    crystal_android_host_callback_void(id).should eq(1)
  end

  it "does not turn an explicit false policy callback into default true" do
    id = UI::CallbackRegistry.register_string_bool(->(value : String) { false })
    begin
      UI::CallbackRegistry.call_string_bool(id, "value").should be_false
      crystal_ui_string_bool_callback_dispatch(id, "value".to_unsafe).should eq(0)
    ensure
      UI::CallbackRegistry.unregister(id)
    end
    UI::CallbackRegistry.call_string_bool(id, "value").should be_true
  end
end
