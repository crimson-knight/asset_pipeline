require "spec"
require "../../../src/ui"
require "../../../src/ui/ax_test"

{% if flag?(:macos) %}
  # Proves a Label's inline trailing link works the way a VoiceOver user
  # reaches it: the link is an AXLink in the accessibility tree, and pressing
  # it runs the Label's handler. The window sits off every screen and never
  # activates the app or becomes key.
  lib LabelTrailingLinkSpecBridge
    fun ap_spec_create_label_window(content_view : Void*) : Void*
    fun ap_spec_pump_label_run_loop : Void
    fun ap_spec_application_is_active : Int32
    fun ap_spec_window_is_key(window : Void*) : Int32
    fun ap_spec_close_label_window(window : Void*) : Void
    fun ap_spec_click_at_ax_point(window : Void*, ax_x : Float64, ax_y : Float64) : Int32
  end

  private LINK_READINESS_TIMEOUT = 5.seconds

  private def find_link(element : UI::AXTest::Element, depth : Int32 = 0) : UI::AXTest::Element?
    return nil if depth > 16
    element.children.each do |child|
      return child if child.role == "AXLink"
      if found = find_link(child, depth + 1)
        return found
      end
    end
    nil
  end

  # Pumps the main run loop until SwiftUI has put the link in the
  # accessibility tree of this process's window.
  private def wait_for_link : UI::AXTest::Element
    app = UI::AXTest::App.connect(Process.pid.to_i32)
    deadline = Time.instant + LINK_READINESS_TIMEOUT
    loop do
      LabelTrailingLinkSpecBridge.ap_spec_pump_label_run_loop
      if link = find_link(app.root)
        return link
      end
      raise "No AXLink appeared within #{LINK_READINESS_TIMEOUT}" if Time.instant >= deadline
    end
  end

  private def pump_until(& : -> Bool) : Nil
    deadline = Time.instant + LINK_READINESS_TIMEOUT
    until yield || Time.instant >= deadline
      LabelTrailingLinkSpecBridge.ap_spec_pump_label_run_loop
    end
  end

  private def center_of(element : UI::AXTest::Element) : {Float64, Float64}
    frame = element.frame
    raise "The element has no frame" unless frame
    {frame[:x] + frame[:width] / 2, frame[:y] + frame[:height] / 2}
  end

  private def with_hosted_label(label : UI::Label, & : Void* ->) : Nil
    page = UI::VStack.new(spacing: 0.0, alignment: UI::Alignment::Leading)
    page << label
    native = UI::AppKit::Renderer.new.render(page)
    window = LabelTrailingLinkSpecBridge.ap_spec_create_label_window(native.handle.ptr!)
    raise "AppKit test window could not be created" if window.null?
    begin
      yield window
      LabelTrailingLinkSpecBridge.ap_spec_application_is_active.should eq(0)
      LabelTrailingLinkSpecBridge.ap_spec_window_is_key(window).should eq(0)
    ensure
      LabelTrailingLinkSpecBridge.ap_spec_close_label_window(window)
      native.teardown!
    end
  end

  private def helper_label(on_link_tap : Proc(Nil)) : UI::Label
    helper = UI::Label.new("Choose where results are saved.")
    helper.trailing_link_text = "How saving works"
    helper.on_trailing_link_tap = on_link_tap
    helper
  end

  describe "UI::Label trailing link on macOS" do
    it "reads as a link inside the paragraph and runs its handler when clicked" do
      presses = 0
      with_hosted_label(helper_label(-> { presses += 1; nil })) do |window|
        link = wait_for_link
        link_frame = link.frame
        report = "link label #{link.label.inspect}, frame #{link_frame}"
        link.label.should eq("How saving works"), report
        presses.should eq(0)

        link_x, link_y = center_of(link)
        LabelTrailingLinkSpecBridge.ap_spec_click_at_ax_point(window, link_x, link_y).should eq(1)
        pump_until { presses > 0 }
        presses.should eq(1), report
      end
    end

    it "does not run the handler when the paragraph text before the link is clicked" do
      presses = 0
      with_hosted_label(helper_label(-> { presses += 1; nil })) do |window|
        link = wait_for_link
        link_frame = link.frame
        raise "The link has no frame" unless link_frame
        app = UI::AXTest::App.connect(Process.pid.to_i32)
        paragraph = app.root.find(role: "AXStaticText", max_depth: 16)
        raise "The paragraph is not in the accessibility tree" unless paragraph
        paragraph_frame = paragraph.frame
        raise "The paragraph has no frame" unless paragraph_frame
        # The paragraph's first word, on the link's line and left of the link.
        text_x = paragraph_frame[:x] + 12.0
        report = "paragraph #{paragraph_frame}, link #{link_frame}"
        text_x.should be < link_frame[:x], report
        LabelTrailingLinkSpecBridge.ap_spec_click_at_ax_point(window, text_x, link_frame[:y] + link_frame[:height] / 2).should eq(1)
        pump_until { presses > 0 }
        presses.should eq(0), report
      end
    end
  end
{% end %}
