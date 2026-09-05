require "spec"
require "../../../src/ui"

describe UI::PropertyMapEditor do
  it "requires an explicit stable identity and has no default persistence" do
    expect_raises(ArgumentError) { UI::PropertyMapEditor.new("") }
    expect_raises(ArgumentError) { UI::PropertyMapEditor.new("x" * 129) }
    editor = UI::PropertyMapEditor.new("lawn-draft")
    editor.initial_outline.should be_nil
    editor.on_save.should be_nil
    editor.on_draft_change.should be_nil
  end

  it "fails explicitly on a non-UIKit renderer instead of displaying an inert editor" do
    map = UI::MapView.new
    map.property_editor = UI::PropertyMapEditor.new("lawn")
    expect_raises(NotImplementedError, /UIKit/) { UI::Web::Renderer.new.render(map) }
  end

  it "keeps ordinary MapView behavior unchanged" do
    map = UI::MapView.new
    map.shows_user_location.should be_false
    map.property_outline.should be_nil
    map.property_editor.should be_nil
    map.camera_revision.should eq(0)
  end
end

describe UI::NativeView do
  it "retains keyed map surfaces without pretending they own a SwiftUI state handle" do
    handle = UI::NativeHandle.new(Pointer(Void).new(0x1234_u64), UI::ReleaseStrategy::Unowned)
    handle.reactive_kind = :property_map
    handle.presentation_identity = "property-map:lawn"
    native = UI::NativeView.new(handle)
    UI::NativeView.build_reuse_registry(native)["property-map:lawn"].should be(native)
    native.handle.state_handle.should be_nil
    native.teardown!
    UI::NativeView.build_reuse_registry(native).should be_empty
  end

  it "replaces callbacks without leaks or dispatch to stale screen closures" do
    native = UI::NativeView.new(UI::NativeHandle.new(Pointer(Void).new(0x1234_u64), UI::ReleaseStrategy::Unowned))
    called = false
    old = native.track_callback_id(UI::CallbackRegistry.register_string(->(raw : String) { called = true; nil }))
    native.clear_callbacks!
    UI::CallbackRegistry.call_string(old, "stale")
    called.should be_false
    current = native.track_callback_id(UI::CallbackRegistry.register_string(->(raw : String) { called = true; nil }))
    UI::CallbackRegistry.call_string(current, "current")
    called.should be_true
    native.teardown!
  end
end
