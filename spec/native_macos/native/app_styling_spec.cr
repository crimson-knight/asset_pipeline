require "spec"
require "../../../src/ui"

# ==========================================================================
# App styling on native macOS views — what an app sets is what renders.
#
# Each example renders real AppKit / SwiftUI views through
# UI::AppKit::Renderer and measures the result: layer properties, fitting
# sizes, or pixels from an offscreen render (`ap_snapshot_view`, no Screen
# Recording permission). Runs in the `make test-macos` lane.
# ==========================================================================

{% if flag?(:macos) %}
  private alias Bridge = UI::AppKit::LibObjCBridge

  # An offscreen render passes through the display color space, so pure
  # sRGB red reads back near (0.94, 0.28, 0.18). Pixel checks only need to
  # tell the expected fill from the others.
  private PIXEL_TOLERANCE = 0.35

  private RED  = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
  private BLUE = UI::Color.new(r: 0.0, g: 0.0, b: 1.0)

  private def render_native(view : UI::View) : Void*
    UI::AppKit::Renderer.new.render(view).handle.ptr!
  end

  private def layer_style(ptr : Void*) : Array(Float64)
    values = Array(Float64).new(18, 0.0)
    Bridge.ap_view_read_layer_style(ptr, values.to_unsafe).should eq(1)
    values
  end

  private def fitting_size(ptr : Void*) : {Float64, Float64}
    values = [0.0, 0.0]
    Bridge.ap_view_fitting_size(ptr, values.to_unsafe)
    {values[0], values[1]}
  end

  # RGBA (0..1) at a point (top-left origin) of an offscreen render.
  private def pixel(ptr : Void*, appearance : String, x : Float64, y : Float64,
                    width : Float64 = 0.0, height : Float64 = 0.0) : Array(Float64)
    snapshot = Bridge.ap_snapshot_view(ptr, appearance, width, height, Pointer(UInt8).null)
    snapshot.null?.should be_false
    values = [0.0, 0.0, 0.0, 0.0]
    Bridge.ap_snapshot_rgba_at(snapshot, x, y, values.to_unsafe).should eq(1)
    Bridge.ap_snapshot_release(snapshot)
    values
  end

  private def color_close?(values : Array(Float64), color : UI::Color, tolerance = 0.08) : Bool
    (values[0] - color.r).abs < tolerance &&
      (values[1] - color.g).abs < tolerance &&
      (values[2] - color.b).abs < tolerance
  end

  # Spin the main run loop so SwiftUI applies an @Published state change.
  private def settle : Nil
    LibRunLoopSpin.CFRunLoopRunInMode(LibRunLoopSpin.kCFRunLoopDefaultMode, 0.2, 0_u8)
  end

  @[Link(framework: "CoreFoundation")]
  lib LibRunLoopSpin
    $kCFRunLoopDefaultMode : Void*
    fun CFRunLoopRunInMode(mode : Void*, seconds : Float64, return_after_source_handled : UInt8) : Int32
  end

  describe "App styling on native macOS views" do
    describe "buttons" do
      it "draws the font size the app sets on first render" do
        plain = render_native(UI::Button.new("Join the room"))
        sized = UI::Button.new("Join the room")
        sized.font = UI::Font.new(size: 30.0, weight: :bold)
        large = render_native(sized)

        fitting_size(large)[0].should be > fitting_size(plain)[0] * 1.4
      end

      it "draws a font assigned after render" do
        button = UI::Button.new("Join the room")
        ptr = render_native(button)
        before = fitting_size(ptr)[0]

        button.font = UI::Font.new(size: 30.0, weight: :bold)
        settle
        Bridge.objc_layout_now(ptr)

        fitting_size(ptr)[0].should be > before * 1.4
      end

      it "fills around the padded label" do
        button = UI::Button.new("Go")
        button.style = UI::ButtonStyle::Borderless
        button.background = RED
        button.padding = UI::EdgeInsets.new(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
        ptr = render_native(button)

        color_close?(pixel(ptr, "light", 3.0, 3.0), RED, PIXEL_TOLERANCE).should be_true
      end
    end

    describe "app-styled buttons (system style with an app fill)" do
      it "draws the app's fill around the padded label in place of the system bezel" do
        button = UI::Button.new("Go")
        button.background = RED
        button.corner_radius = 4.0
        button.padding = UI::EdgeInsets.new(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
        ptr = render_native(button)

        color_close?(pixel(ptr, "light", 5.0, 5.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel(ptr, "dark", 5.0, 5.0), RED, PIXEL_TOLERANCE).should be_true
      end

      it "fills the whole minimum height, not only the label" do
        button = UI::Button.new("Go")
        button.background = RED
        button.minimum_height = 44.0
        button.padding = UI::EdgeInsets.new(top: 0.0, leading: 12.0, bottom: 0.0, trailing: 12.0)
        row = UI::HStack.new(alignment: UI::Alignment::Top)
        row << button

        values = pixel(render_native(row), "light", 4.0, 41.0)
        color_close?(values, RED, PIXEL_TOLERANCE).should be_true
        values[3].should be > 0.9
      end

      it "draws a larger font on a borderless button, where the chrome does not change" do
        plain = UI::Button.new("Join the room")
        plain.style = UI::ButtonStyle::Borderless
        sized = UI::Button.new("Join the room")
        sized.style = UI::ButtonStyle::Borderless
        sized.font = UI::Font.new(size: 30.0, weight: :bold)

        fitting_size(render_native(sized))[0].should be > fitting_size(render_native(plain))[0] * 1.8
      end

      it "dims the whole fill, not only the label, when disabled" do
        enabled = UI::Button.new("Go")
        enabled.background = RED
        enabled.padding = UI::EdgeInsets.new(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
        disabled = UI::Button.new("Go")
        disabled.background = RED
        disabled.padding = UI::EdgeInsets.new(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
        disabled.disabled = true

        # Wrapped in a stack: an offscreen render skips the opacity of the
        # root hosting view itself, so the button must not be the root.
        enabled_row = UI::HStack.new
        enabled_row << enabled
        disabled_row = UI::HStack.new
        disabled_row << disabled
        enabled_red = pixel(render_native(enabled_row), "light", 3.0, 3.0)
        disabled_red = pixel(render_native(disabled_row), "light", 3.0, 3.0)
        # The offscreen render keeps transparency, so the dimmed fill shows
        # as a lower alpha at a point inside the padding.
        enabled_red[3].should be_close(1.0, 0.01)
        disabled_red[3].should be < 0.6
      end
    end

    describe "labels" do
      it "fills around the padded text" do
        label = UI::Label.new("Pill")
        label.background = RED
        label.padding = UI::EdgeInsets.new(top: 12.0, leading: 12.0, bottom: 12.0, trailing: 12.0)
        ptr = render_native(label)

        color_close?(pixel(ptr, "light", 3.0, 3.0), RED, PIXEL_TOLERANCE).should be_true
      end

      it "draws the system monospace family" do
        proportional = UI::Label.new("iiiiiiiiii")
        proportional.font = UI::Font.new(size: 14.0)
        mono = UI::Label.new("iiiiiiiiii")
        mono.font = UI::Font.new(family: "monospace", size: 14.0)

        fitting_size(render_native(mono))[0].should be > fitting_size(render_native(proportional))[0] * 1.5
      end

      it "draws a named family" do
        proportional = UI::Label.new("iiiiiiiiii")
        proportional.font = UI::Font.new(size: 14.0)
        courier = UI::Label.new("iiiiiiiiii")
        courier.font = UI::Font.new(family: "Courier", size: 14.0)

        fitting_size(render_native(courier))[0].should be > fitting_size(render_native(proportional))[0] * 1.5
      end

      it "falls back to the system face when the family is missing" do
        system = UI::Label.new("iiiiiiiiii")
        system.font = UI::Font.new(size: 14.0)
        missing = UI::Label.new("iiiiiiiiii")
        missing.font = UI::Font.new(family: "NoSuchFace-Regular", size: 14.0)

        fitting_size(render_native(missing))[0].should be_close(fitting_size(render_native(system))[0], 0.5)
      end
    end

    describe "stacks" do
      it "rounds, borders and shadows a VStack" do
        stack = UI::VStack.new
        stack.background = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
        stack.corner_radius = 12.0
        stack.border_width = 1.5
        stack.border_color = BLUE
        stack.shadow_radius = 8.0
        stack.shadow_color = UI::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.3)
        stack.shadow_offset_y = 4.0
        style = layer_style(render_native(stack))

        style[0].should eq(12.0)            # corner radius
        style[1].should eq(1.5)             # border width
        style[4].should be_close(1.0, 0.01) # border blue
        style[10].should eq(8.0)            # shadow radius
        style[12].should eq(-4.0)           # 4pt DOWN in AppKit's y-up layer space
        style[13].should eq(1.0)            # opacity carried by the color's alpha
        style[17].should be_close(0.3, 0.01)
      end

      it "shadows an HStack and a ZStack" do
        hstack = UI::HStack.new
        hstack.shadow_radius = 5.0
        layer_style(render_native(hstack))[10].should eq(5.0)

        zstack = UI::ZStack.new
        zstack.shadow_radius = 6.0
        layer_style(render_native(zstack))[10].should eq(6.0)
      end

      it "leaves a stack without a shadow untouched" do
        stack = UI::VStack.new
        layer_style(render_native(stack))[13].should eq(0.0)
      end
    end

    describe "HStack padding" do
      it "honors top and bottom padding" do
        child = UI::VStack.new
        child.minimum_height = 40.0
        child.minimum_width = 40.0
        child.maximum_width = 40.0
        row = UI::HStack.new
        row << child
        row.padding = UI::EdgeInsets.new(top: 20.0, leading: 0.0, bottom: 30.0, trailing: 0.0)

        fitting_size(render_native(row))[1].should be_close(90.0, 0.5)
      end

      it "honors leading and trailing padding on a leading-aligned VStack" do
        child = UI::VStack.new
        child.minimum_height = 20.0
        child.minimum_width = 100.0
        child.maximum_width = 100.0
        column = UI::VStack.new(alignment: UI::Alignment::Leading)
        column << child
        column.padding = UI::EdgeInsets.new(top: 0.0, leading: 18.0, bottom: 0.0, trailing: 18.0)

        fitting_size(render_native(column))[0].should be_close(136.0, 0.5)
      end
    end

    describe "dynamic colors" do
      it "resolves a stack fill for the current appearance and follows a switch" do
        stack = UI::VStack.new
        stack.background = UI::Color.dynamic(light: RED, dark: BLUE)
        ptr = render_native(stack)

        Bridge.ap_view_set_appearance(ptr, "light")
        settle
        style = layer_style(ptr)
        color_close?(style[6, 4], RED).should be_true

        Bridge.ap_view_set_appearance(ptr, "dark")
        settle
        style = layer_style(ptr)
        color_close?(style[6, 4], BLUE).should be_true
      end

      it "resolves a SwiftUI label fill per appearance" do
        label = UI::Label.new("Ink")
        label.background = UI::Color.dynamic(light: RED, dark: BLUE)
        label.padding = UI::EdgeInsets.new(top: 10.0, leading: 10.0, bottom: 10.0, trailing: 10.0)
        ptr = render_native(label)

        color_close?(pixel(ptr, "light", 3.0, 3.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel(ptr, "dark", 3.0, 3.0), BLUE, PIXEL_TOLERANCE).should be_true
      end

      it "resolves a stack fill in an offscreen render per appearance" do
        stack = UI::VStack.new
        stack.background = UI::Color.dynamic(light: RED, dark: BLUE)
        ptr = render_native(stack)

        color_close?(pixel(ptr, "light", 5.0, 5.0, 40.0, 40.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel(ptr, "dark", 5.0, 5.0, 40.0, 40.0), BLUE, PIXEL_TOLERANCE).should be_true
      end
    end
  end
{% end %}
