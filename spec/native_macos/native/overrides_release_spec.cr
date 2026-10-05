require "spec"
require "../../../src/ui"

{% if flag?(:macos) %}
  # Proves the AppKit renderer gives back the `APSK*Overrides` object it
  # allocates for every SwiftKit widget. `+new` hands the renderer one
  # retain and the Swift view keeps its own reference, so once the renderer
  # releases its retain the overrides live exactly as long as the view.
  # Before the release existed every render left one overrides object
  # behind for the life of the process (640 bytes per Label render in
  # Scribe's dictation pill).
  lib OverridesLifetimeSpecBridge
    fun ap_spec_overrides_track(class_name : UInt8*) : Int32
    fun ap_spec_overrides_live_count : Int64
  end

  private RENDER_COUNT = 20

  private def track_overrides(class_name : String) : Nil
    OverridesLifetimeSpecBridge.ap_spec_overrides_track(class_name).should eq(1)
  end

  # Renders `RENDER_COUNT` views from `build` and releases each native view
  # inside one autorelease pool, then returns how many tracked overrides
  # objects are still alive.
  private def live_overrides_after_render_and_release(& : -> UI::View) : Int64
    UI::ObjC.autoreleasepool do
      RENDER_COUNT.times do
        native = UI::AppKit::Renderer.new.render(yield)
        native.handle.release!
      end
    end
    OverridesLifetimeSpecBridge.ap_spec_overrides_live_count
  end

  describe "SwiftKit overrides ownership in the AppKit renderer" do
    it "releases a Label's overrides once its view is released" do
      track_overrides("APSKLabelOverrides")
      before = OverridesLifetimeSpecBridge.ap_spec_overrides_live_count

      live_overrides_after_render_and_release { UI::Label.new("Listening") }.should eq(before)
    end

    it "releases a Button's overrides once its view is released" do
      track_overrides("APSKButtonOverrides")
      before = OverridesLifetimeSpecBridge.ap_spec_overrides_live_count

      live_overrides_after_render_and_release { UI::Button.new("Stop") }.should eq(before)
    end

    it "keeps a Label's overrides alive while its view is alive" do
      track_overrides("APSKLabelOverrides")
      before = OverridesLifetimeSpecBridge.ap_spec_overrides_live_count

      native = UI::AppKit::Renderer.new.render(UI::Label.new("Listening"))
      OverridesLifetimeSpecBridge.ap_spec_overrides_live_count.should eq(before + 1)

      native.handle.release!
    end
  end
{% end %}
