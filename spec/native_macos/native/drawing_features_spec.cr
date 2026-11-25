require "spec"
require "../../../src/ui"

# ==========================================================================
# Drawing features on native macOS views: dynamic shape fills, clean button
# borders, rotation, stack gradients with grain, interaction-state renders,
# and the fitting height of a column in a padded row.
#
# Each example renders real AppKit / SwiftUI views through
# UI::AppKit::Renderer and measures pixels from an offscreen render
# (`ap_snapshot_view`, top-left origin, one pixel per point) or layer
# properties. Runs in the `make test-macos` lane.
# ==========================================================================

{% if flag?(:macos) %}
  private alias Bridge = UI::AppKit::LibObjCBridge

  # An offscreen render passes through the display color space, so pure
  # sRGB red reads back near (0.94, 0.28, 0.18). Pixel checks only need to
  # tell the expected fill from the others.
  private PIXEL_TOLERANCE = 0.35

  private RED    = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
  private BLUE   = UI::Color.new(r: 0.0, g: 0.0, b: 1.0)
  private GREEN  = UI::Color.new(r: 0.0, g: 1.0, b: 0.0)
  private YELLOW = UI::Color.new(r: 1.0, g: 1.0, b: 0.0)
  private GRAY   = UI::Color.new(r: 0.5, g: 0.5, b: 0.5)

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

  # An offscreen render of `ptr`, read point by point with `pixel_at`.
  private def snapshot_of(ptr : Void*, appearance : String, interaction_state : String = "none",
                          width : Float64 = 0.0, height : Float64 = 0.0) : Void*
    snapshot = Bridge.ap_snapshot_view_in_interaction_state(ptr, appearance, width, height,
      Pointer(UInt8).null, interaction_state)
    snapshot.null?.should be_false
    snapshot
  end

  # RGBA (0..1) at a point of a snapshot.
  private def pixel_at(snapshot : Void*, points_from_left : Float64, points_from_top : Float64) : Array(Float64)
    values = [0.0, 0.0, 0.0, 0.0]
    Bridge.ap_snapshot_rgba_at(snapshot, points_from_left, points_from_top, values.to_unsafe).should eq(1)
    values
  end

  # RGBA at one point of a fresh offscreen render.
  private def pixel(ptr : Void*, appearance : String, points_from_left : Float64, points_from_top : Float64,
                    interaction_state : String = "none") : Array(Float64)
    snapshot = snapshot_of(ptr, appearance, interaction_state)
    values = pixel_at(snapshot, points_from_left, points_from_top)
    Bridge.ap_snapshot_release(snapshot)
    values
  end

  private def color_close?(values : Array(Float64), color : UI::Color, tolerance = 0.08) : Bool
    (values[0] - color.r).abs < tolerance &&
      (values[1] - color.g).abs < tolerance &&
      (values[2] - color.b).abs < tolerance
  end

  # Largest channel difference between two RGBA readings, alpha included.
  private def channel_difference(first : Array(Float64), second : Array(Float64)) : Float64
    (0..3).max_of { |channel| (first[channel] - second[channel]).abs }
  end

  private def blue_ink?(values : Array(Float64)) : Bool
    values[3] > 0.3 && values[2] > 0.6 && values[0] < 0.45 && values[1] < 0.45
  end

  private def red_ink?(values : Array(Float64)) : Bool
    values[3] > 0.5 && values[0] > 0.6 && values[1] < 0.5 && values[2] < 0.5
  end

  # Spin the main run loop so SwiftUI and appearance callbacks settle.
  private def settle : Nil
    LibRunLoopSpinForDrawing.CFRunLoopRunInMode(LibRunLoopSpinForDrawing.kCFRunLoopDefaultMode, 0.2, 0_u8)
  end

  @[Link(framework: "CoreFoundation")]
  lib LibRunLoopSpinForDrawing
    $kCFRunLoopDefaultMode : Void*
    fun CFRunLoopRunInMode(mode : Void*, seconds : Float64, return_after_source_handled : UInt8) : Int32
  end

  private def square_box(side : Float64) : UI::VStack
    box = UI::VStack.new
    box.minimum_width = side
    box.maximum_width = side
    box.minimum_height = side
    box
  end

  private def padded_row(padding : Float64) : UI::HStack
    row = UI::HStack.new
    row.padding = UI::EdgeInsets.new(top: padding, leading: padding, bottom: padding, trailing: padding)
    row
  end

  private def bordered_button : UI::Button
    button = UI::Button.new("Join the room")
    button.background = UI::Color.new(r: 1.0, g: 0.9, b: 0.8)
    button.corner_radius = 16.0
    button.border_width = 2.0
    button.border_color = BLUE
    button.padding = UI::EdgeInsets.new(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0)
    button
  end

  describe "Drawing features on native macOS views" do
    describe "shapes with a dynamic fill" do
      it "draws a Rectangle's light value in light and its dark value in dark" do
        rectangle = UI::Rectangle.new(width: 40.0, height: 40.0)
        rectangle.fill_color = UI::Color.dynamic(light: RED, dark: BLUE)
        ptr = render_native(rectangle)

        color_close?(pixel(ptr, "light", 20.0, 20.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel(ptr, "dark", 20.0, 20.0), BLUE, PIXEL_TOLERANCE).should be_true
      end

      it "follows a live appearance switch" do
        rectangle = UI::Rectangle.new(width: 40.0, height: 40.0)
        rectangle.fill_color = UI::Color.dynamic(light: RED, dark: BLUE)
        rectangle.stroke_color = UI::Color.dynamic(light: GREEN, dark: YELLOW)
        rectangle.stroke_width = 2.0
        ptr = render_native(rectangle)

        Bridge.ap_view_set_appearance(ptr, "light")
        settle
        style = layer_style(ptr)
        color_close?(style[6, 4], RED).should be_true
        color_close?(style[2, 4], GREEN).should be_true

        Bridge.ap_view_set_appearance(ptr, "dark")
        settle
        style = layer_style(ptr)
        color_close?(style[6, 4], BLUE).should be_true
        color_close?(style[2, 4], YELLOW).should be_true
      end

      it "draws RoundedRectangle, Circle and Capsule fills per appearance" do
        rounded = UI::RoundedRectangle.new(width: 40.0, height: 40.0)
        rounded.fill_color = UI::Color.dynamic(light: RED, dark: BLUE)
        circle = UI::Circle.new(size: 40.0)
        circle.fill_color = UI::Color.dynamic(light: RED, dark: BLUE)
        capsule = UI::Capsule.new(width: 60.0, height: 30.0)
        capsule.fill_color = UI::Color.dynamic(light: RED, dark: BLUE)

        # A Capsule does not pin its own size, so its render is sized here.
        [{render_native(rounded), 0.0, 0.0}, {render_native(circle), 0.0, 0.0},
         {render_native(capsule), 60.0, 30.0}].each do |(shape_ptr, render_width, render_height)|
          {"light" => RED, "dark" => BLUE}.each do |appearance, expected_fill|
            snapshot = snapshot_of(shape_ptr, appearance, "none", render_width, render_height)
            color_close?(pixel_at(snapshot, 20.0, 15.0), expected_fill, PIXEL_TOLERANCE).should be_true
            Bridge.ap_snapshot_release(snapshot)
          end
        end
      end
    end

    describe "app-styled buttons with a border" do
      it "draws the border inside the pill and nothing beside it" do
        row = padded_row(10.0)
        row << bordered_button
        ptr = render_native(row)
        row_width, row_height = fitting_size(ptr)
        pill_right_edge = row_width - 10.0
        middle = (row_height / 2.0).floor

        {"light", "dark"}.each do |appearance|
          snapshot = snapshot_of(ptr, appearance)
          blue_ink?(pixel_at(snapshot, 10.0, middle)).should be_true
          blue_ink?(pixel_at(snapshot, pill_right_edge - 1.0, middle)).should be_true
          blue_ink?(pixel_at(snapshot, 10.0 + 40.0, 10.0)).should be_true
          (0.0..9.0).step(1.0).each do |outside_x|
            blue_ink?(pixel_at(snapshot, outside_x, middle)).should be_false
            blue_ink?(pixel_at(snapshot, row_width - 1.0 - outside_x, middle)).should be_false
          end
          Bridge.ap_snapshot_release(snapshot)
        end
      end

      it "draws no border ink outside the outline of the unbordered pill" do
        bordered_row = padded_row(10.0)
        bordered_row << bordered_button
        unbordered_button = bordered_button
        unbordered_button.border_width = 0.0
        unbordered_row = padded_row(10.0)
        unbordered_row << unbordered_button
        bordered_ptr = render_native(bordered_row)
        unbordered_ptr = render_native(unbordered_row)
        row_width, row_height = fitting_size(bordered_ptr)

        {"light", "dark"}.each do |appearance|
          bordered = snapshot_of(bordered_ptr, appearance)
          unbordered = snapshot_of(unbordered_ptr, appearance)
          count_of_stray_pixels = 0
          (0...row_height.to_i).each do |pixel_y|
            (0...row_width.to_i).each do |pixel_x|
              outside_the_pill = pixel_at(unbordered, pixel_x.to_f, pixel_y.to_f)[3] < 0.05
              inked = pixel_at(bordered, pixel_x.to_f, pixel_y.to_f)[3] > 0.25
              count_of_stray_pixels += 1 if outside_the_pill && inked
            end
          end
          count_of_stray_pixels.should eq(0)
          Bridge.ap_snapshot_release(bordered)
          Bridge.ap_snapshot_release(unbordered)
        end
      end
    end

    describe "rotation_degrees" do
      it "turns a view clockwise about its center for positive degrees" do
        tilted_bar = UI::Rectangle.new(width: 60.0, height: 10.0)
        tilted_bar.fill_color = RED
        tilted_bar.rotation_degrees = 30.0
        row = padded_row(30.0)
        row << tilted_bar
        snapshot = snapshot_of(render_native(row), "light")

        # Center (60, 35); 20pt right of it the bar has dropped 11.5pt.
        red_ink?(pixel_at(snapshot, 60.0, 35.0)).should be_true
        red_ink?(pixel_at(snapshot, 80.0, 46.0)).should be_true
        red_ink?(pixel_at(snapshot, 40.0, 24.0)).should be_true
        red_ink?(pixel_at(snapshot, 80.0, 24.0)).should be_false
        red_ink?(pixel_at(snapshot, 88.0, 35.0)).should be_false
        Bridge.ap_snapshot_release(snapshot)
      end

      it "sets the layer rotation and keeps the layout size" do
        plain_label = UI::Label.new("STORY")
        tilted_label = UI::Label.new("STORY")
        tilted_label.rotation_degrees = -6.0
        plain_row = padded_row(12.0)
        plain_row << plain_label
        tilted_row = padded_row(12.0)
        tilted_row << tilted_label

        plain_ptr = render_native(plain_row)
        tilted_native = UI::AppKit::Renderer.new.render(tilted_row)
        tilted_ptr = tilted_native.handle.ptr!
        fitting_size(tilted_ptr).should eq(fitting_size(plain_ptr))

        Bridge.ap_snapshot_release(snapshot_of(tilted_ptr, "light"))
        label_ptr = tilted_native.children.first.handle.ptr!
        Bridge.ap_view_read_rotation_degrees(label_ptr).should be_close(-6.0, 0.01)
      end

      it "rotates a stack and a SwiftUI-hosted button" do
        stack = UI::VStack.new
        stack.rotation_degrees = 12.0
        button = UI::Button.new("Go")
        button.rotation_degrees = -6.0

        Bridge.ap_view_read_rotation_degrees(render_native(stack)).should be_close(12.0, 0.01)
        Bridge.ap_view_read_rotation_degrees(render_native(button)).should be_close(-6.0, 0.01)
      end
    end

    describe "stack background gradients" do
      it "draws a linear gradient of dynamic stops in each appearance" do
        box = square_box(100.0)
        box.background_gradient = UI::BackgroundGradient.linear([
          UI::GradientStop.new(color: UI::Color.dynamic(light: RED, dark: BLUE), location: 0.0),
          UI::GradientStop.new(color: UI::Color.dynamic(light: BLUE, dark: RED), location: 1.0),
        ])
        ptr = render_native(box)

        light = snapshot_of(ptr, "light")
        color_close?(pixel_at(light, 50.0, 2.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel_at(light, 50.0, 97.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(light)

        dark = snapshot_of(ptr, "dark")
        color_close?(pixel_at(dark, 50.0, 2.0), BLUE, PIXEL_TOLERANCE).should be_true
        color_close?(pixel_at(dark, 50.0, 97.0), RED, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(dark)
      end

      it "runs a linear gradient between the points it names" do
        box = square_box(100.0)
        box.background_gradient = UI::BackgroundGradient.linear([
          UI::GradientStop.new(color: RED, location: 0.0),
          UI::GradientStop.new(color: BLUE, location: 1.0),
        ], from: UI::UnitPoint.new(0.0, 0.5), to: UI::UnitPoint.new(1.0, 0.5))
        snapshot = snapshot_of(render_native(box), "light")

        color_close?(pixel_at(snapshot, 2.0, 50.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel_at(snapshot, 97.0, 50.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(snapshot)
      end

      it "draws a radial gradient with three stops from the center out" do
        box = square_box(100.0)
        box.background_gradient = UI::BackgroundGradient.radial([
          UI::GradientStop.new(color: UI::Color.dynamic(light: RED, dark: BLUE), location: 0.0),
          UI::GradientStop.new(color: GREEN, location: 0.5),
          UI::GradientStop.new(color: UI::Color.dynamic(light: BLUE, dark: RED), location: 1.0),
        ])
        ptr = render_native(box)

        light = snapshot_of(ptr, "light")
        color_close?(pixel_at(light, 50.0, 50.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel_at(light, 2.0, 2.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(light)

        dark = snapshot_of(ptr, "dark")
        color_close?(pixel_at(dark, 50.0, 50.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(dark)
      end

      it "lays a static grain over the gradient at the opacity the app sets" do
        flat_gray = [
          UI::GradientStop.new(color: GRAY, location: 0.0),
          UI::GradientStop.new(color: GRAY, location: 1.0),
        ]
        smooth = square_box(100.0)
        smooth.background_gradient = UI::BackgroundGradient.linear(flat_gray)
        grainy = square_box(100.0)
        grainy.background_gradient = UI::BackgroundGradient.linear(flat_gray)
        grainy.grain_opacity = 0.3

        spread_of_reds = ->(ptr : Void*) do
          snapshot = snapshot_of(ptr, "light")
          list_of_reds = (0...40).map { |step| pixel_at(snapshot, 10.0 + step * 2.0, 50.0)[0] }
          Bridge.ap_snapshot_release(snapshot)
          list_of_reds.max - list_of_reds.min
        end

        spread_of_reds.call(render_native(smooth)).should be < 0.02
        spread_of_reds.call(render_native(grainy)).should be > 0.1
        spread_of_reds.call(render_native(grainy)).should be < 0.5
      end

      it "draws a gradient on an HStack and a ZStack, under their children" do
        row = UI::HStack.new
        row.minimum_width = 100.0
        row.maximum_width = 100.0
        row.minimum_height = 40.0
        row.background_gradient = UI::BackgroundGradient.linear([
          UI::GradientStop.new(color: RED, location: 0.0),
          UI::GradientStop.new(color: RED, location: 1.0),
        ])
        swatch = UI::Rectangle.new(width: 20.0, height: 20.0)
        swatch.fill_color = BLUE
        row << swatch
        row_snapshot = snapshot_of(render_native(row), "light")
        color_close?(pixel_at(row_snapshot, 3.0, 3.0), RED, PIXEL_TOLERANCE).should be_true
        color_close?(pixel_at(row_snapshot, 10.0, 20.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(row_snapshot)

        layers = UI::ZStack.new
        layers.minimum_width = 60.0
        layers.maximum_width = 60.0
        layers.minimum_height = 60.0
        layers.background_gradient = UI::BackgroundGradient.radial([
          UI::GradientStop.new(color: BLUE, location: 0.0),
          UI::GradientStop.new(color: BLUE, location: 1.0),
        ])
        layers_snapshot = snapshot_of(render_native(layers), "light")
        color_close?(pixel_at(layers_snapshot, 30.0, 30.0), BLUE, PIXEL_TOLERANCE).should be_true
        Bridge.ap_snapshot_release(layers_snapshot)
      end

      it "leaves the stack's fitting size unchanged" do
        plain = UI::VStack.new
        plain << UI::Label.new("Drafting Room")
        painted = UI::VStack.new
        painted << UI::Label.new("Drafting Room")
        painted.background_gradient = UI::BackgroundGradient.linear([
          UI::GradientStop.new(color: RED, location: 0.0),
          UI::GradientStop.new(color: BLUE, location: 1.0),
        ])
        painted.grain_opacity = 0.2

        fitting_size(render_native(painted)).should eq(fitting_size(render_native(plain)))
      end

      it "needs two or more stops" do
        expect_raises(UI::GradientNeedsTwoStopsError) do
          UI::BackgroundGradient.linear([UI::GradientStop.new(color: RED, location: 0.0)])
        end
      end
    end

    describe "offscreen renders in an interaction state" do
      it "draws hover, pressed and focused, and returns to the resting state" do
        row = padded_row(10.0)
        row << bordered_button
        ptr = render_native(row)
        fill_point = {30.0, 16.0}
        ring_point = {8.5, 22.0}

        resting = snapshot_of(ptr, "light")
        resting_fill = pixel_at(resting, *fill_point)
        resting_ring = pixel_at(resting, *ring_point)
        Bridge.ap_snapshot_release(resting)

        hover = snapshot_of(ptr, "light", "hover")
        channel_difference(pixel_at(hover, *fill_point), resting_fill).should be > 0.03
        Bridge.ap_snapshot_release(hover)

        pressed = snapshot_of(ptr, "light", "pressed")
        pressed_fill = pixel_at(pressed, *fill_point)
        pressed_fill[3].should be < 0.9
        resting_fill[3].should be_close(1.0, 0.01)
        Bridge.ap_snapshot_release(pressed)

        focused = snapshot_of(ptr, "light", "focused")
        channel_difference(pixel_at(focused, *ring_point), resting_ring).should be > 0.2
        Bridge.ap_snapshot_release(focused)

        after = snapshot_of(ptr, "light")
        channel_difference(pixel_at(after, *fill_point), resting_fill).should be < 0.01
        channel_difference(pixel_at(after, *ring_point), resting_ring).should be < 0.01
        Bridge.ap_snapshot_release(after)
      end
    end

    describe "a column in a top-aligned row with padding" do
      it "keeps its own fitting height and honors maximum_height" do
        row = UI::HStack.new(alignment: UI::Alignment::Top)
        row.padding = UI::EdgeInsets.new(top: 8.0, leading: 0.0, bottom: 8.0, trailing: 0.0)
        empty_column = UI::VStack.new
        empty_column.minimum_width = 30.0
        capped_column = UI::VStack.new
        capped_column.minimum_width = 30.0
        capped_column.maximum_height = 20.0
        text_column = UI::VStack.new
        text_column << UI::Label.new("one")
        tall_column = square_box(100.0)
        row << empty_column << capped_column << text_column << tall_column

        native = UI::AppKit::Renderer.new.render(row)
        Bridge.ap_snapshot_release(snapshot_of(native.handle.ptr!, "light"))
        list_of_heights = native.children.map { |column| Bridge.objc_get_frame(column.handle.ptr!).height }

        list_of_heights[0].should be < 1.0
        list_of_heights[1].should be <= 20.0
        list_of_heights[2].should be < 30.0
        list_of_heights[3].should eq(100.0)
        fitting_size(native.handle.ptr!)[1].should be_close(116.0, 0.5)
      end

      it "still stretches children in a Fill row" do
        row = UI::HStack.new(alignment: UI::Alignment::Fill)
        row.padding = UI::EdgeInsets.new(top: 8.0, leading: 0.0, bottom: 8.0, trailing: 0.0)
        stretched_column = UI::VStack.new
        stretched_column.minimum_width = 30.0
        row << stretched_column << square_box(100.0)

        native = UI::AppKit::Renderer.new.render(row)
        Bridge.ap_snapshot_release(snapshot_of(native.handle.ptr!, "light"))
        Bridge.objc_get_frame(native.children.first.handle.ptr!).height.should eq(100.0)
      end
    end
  end
{% end %}
