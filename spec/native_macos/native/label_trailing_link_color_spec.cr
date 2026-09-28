require "spec"
require "../../../src/ui"

{% if flag?(:macos) %}
  # Proves the ink of a Label's inline trailing link reaches the pixels the
  # AppKit renderer draws. SwiftUI draws a link in the accent color unless it
  # is told otherwise, so a helper paragraph's link used to read as a blue
  # control in the middle of dark red text. Each Label is drawn offscreen into
  # an sRGB bitmap at 2x and its opaque ink pixels are sorted by hue.
  lib LabelTrailingLinkColorSpecBridge
    fun ap_spec_tracking_window_new(view : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_tracking_capture(window : Void*, scale : Float64, out_rgba : UInt8*, capacity : Int64, out_size : Int32*) : Int32
    fun ap_spec_tracking_application_is_active : Int32
    fun ap_spec_tracking_window_is_key(window : Void*) : Int32
    fun ap_spec_tracking_window_close(window : Void*) : Void
  end

  private LINK_COLOR_CAPTURE_SCALE    = 2.0
  private LINK_COLOR_CAPTURE_CAPACITY = 4_i64 * 2048 * 2048
  # Premultiplied coverage above which a pixel counts as ink.
  private LINK_COLOR_INK_ALPHA = 200
  # How far one channel must lead the other two for a pixel to count as that hue.
  private LINK_COLOR_HUE_MARGIN = 40

  private LINK_PARAGRAPH_INK = UI::Color.new(r: 0x7A / 255.0, g: 0x2E / 255.0, b: 0x1F / 255.0)
  private LINK_OWN_INK       = UI::Color.new(r: 0x1F / 255.0, g: 0x7A / 255.0, b: 0x2E / 255.0)

  # Opaque ink pixels in a capture, counted by the channel that leads.
  private record LinkInkCount, red_ink : Int32, green_ink : Int32, blue_ink : Int32

  private def count_link_ink(pixels : Bytes, width : Int32, height : Int32) : LinkInkCount
    red_ink = 0
    green_ink = 0
    blue_ink = 0
    (width * height).times do |index|
      offset = index * 4
      next if pixels[offset + 3] < LINK_COLOR_INK_ALPHA
      red = pixels[offset].to_i
      green = pixels[offset + 1].to_i
      blue = pixels[offset + 2].to_i
      red_ink += 1 if red > green + LINK_COLOR_HUE_MARGIN && red > blue + LINK_COLOR_HUE_MARGIN
      green_ink += 1 if green > red + LINK_COLOR_HUE_MARGIN && green > blue + LINK_COLOR_HUE_MARGIN
      blue_ink += 1 if blue > red + LINK_COLOR_HUE_MARGIN && blue > green + LINK_COLOR_HUE_MARGIN
    end
    LinkInkCount.new(red_ink, green_ink, blue_ink)
  end

  private def linked_paragraph(paragraph : String, link_color : UI::Color?) : UI::Label
    label = UI::Label.new(paragraph)
    label.font = UI::Font.new(size: 20.0, weight: :bold)
    label.text_color = LINK_PARAGRAPH_INK
    label.trailing_link_text = "How saving works"
    label.trailing_link_color = link_color
    label
  end

  private def capture_link_ink(label : UI::Label) : LinkInkCount
    native = UI::AppKit::Renderer.new.render(label)
    window = LabelTrailingLinkColorSpecBridge.ap_spec_tracking_window_new(native.handle.ptr!, 420.0, 60.0)
    raise "The offscreen window could not be created" if window.null?
    begin
      pixels = Bytes.new(LINK_COLOR_CAPTURE_CAPACITY)
      size = StaticArray(Int32, 2).new(0)
      captured = LabelTrailingLinkColorSpecBridge.ap_spec_tracking_capture(
        window, LINK_COLOR_CAPTURE_SCALE, pixels.to_unsafe, LINK_COLOR_CAPTURE_CAPACITY, size.to_unsafe)
      raise "The Label could not be captured" if captured == 0
      LabelTrailingLinkColorSpecBridge.ap_spec_tracking_application_is_active.should eq(0)
      LabelTrailingLinkColorSpecBridge.ap_spec_tracking_window_is_key(window).should eq(0)
      count_link_ink(pixels, size[0], size[1])
    ensure
      LabelTrailingLinkColorSpecBridge.ap_spec_tracking_window_close(window)
      native.teardown!
    end
  end

  describe "UI::Label trailing link color on macOS" do
    it "draws the link in the label's own ink by default, not the accent color" do
      # An empty paragraph leaves only the link, so every ink pixel is link ink.
      link_only = capture_link_ink(linked_paragraph("", nil))
      report = link_only.to_s
      link_only.red_ink.should be > 100, report
      link_only.blue_ink.should eq(0), report
      link_only.green_ink.should eq(0), report
    end

    it "draws the link in its own color when one is set" do
      paragraph = capture_link_ink(linked_paragraph("Saved.", LINK_OWN_INK))
      report = paragraph.to_s
      paragraph.red_ink.should be > 50, report
      paragraph.green_ink.should be > 100, report
      paragraph.blue_ink.should eq(0), report
    end
  end
{% end %}
