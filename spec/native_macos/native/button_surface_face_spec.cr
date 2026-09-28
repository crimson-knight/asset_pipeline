require "spec"
require "../../../src/ui"

{% if flag?(:macos) %}
  # Proves a native UI::Button with a surface-craft face draws that face the
  # way a designed control face needs it: the gradient above the button's own background,
  # inside its rounded corners, the label placed by text_alignment, and the
  # face swapping for hover and press, from a forced preview state and from a
  # real mouse press. Each button is drawn offscreen into an sRGB bitmap at
  # 2x; the window never activates the app or becomes key.
  lib ButtonSurfaceFaceSpecBridge
    fun ap_spec_tracking_window_new(view : Void*, width : Float64, height : Float64) : Void*
    fun ap_spec_tracking_capture(window : Void*, scale : Float64, out_rgba : UInt8*, capacity : Int64, out_size : Int32*) : Int32
    fun ap_spec_tracking_send_mouse(window : Void*, x : Float64, y : Float64, is_down : Int32) : Int32
    fun ap_spec_tracking_application_is_active : Int32
    fun ap_spec_tracking_window_is_key(window : Void*) : Int32
    fun ap_spec_tracking_window_close(window : Void*) : Void
  end

  private FACE_CAPTURE_SCALE     = 2.0
  private FACE_CAPTURE_CAPACITY  = 4_i64 * 2048 * 2048
  private FACE_WIDTH             = 200.0
  private FACE_HEIGHT            =  36.0
  private FACE_CORNER_RADIUS     =  10.0
  private FACE_CHANNEL_TOLERANCE =     3

  private RESTING_FILL = UI::Color.new(r: 0xE6 / 255.0, g: 0xE1 / 255.0, b: 0xD6 / 255.0)
  private HOVERED_FILL = UI::Color.new(r: 0x9F / 255.0, g: 0xD8 / 255.0, b: 0xA8 / 255.0)
  private PRESSED_FILL = UI::Color.new(r: 0xD8 / 255.0, g: 0x8C / 255.0, b: 0x7A / 255.0)
  private BASE_GREEN   = UI::Color.new(r: 0.0, g: 1.0, b: 0.0)
  private LABEL_INK    = UI::Color.new(r: 0.0, g: 0.0, b: 0.0)

  # A 2x sRGB capture of the button's window.
  private record FaceCapture, pixels : Bytes, pixel_width : Int32, pixel_height : Int32 do
    # RGBA at a point, in points from the top-left corner.
    def rgba_at(points_from_left : Float64, points_from_top : Float64) : Array(Int32)
      column = (points_from_left * FACE_CAPTURE_SCALE).to_i.clamp(0, pixel_width - 1)
      row = (points_from_top * FACE_CAPTURE_SCALE).to_i.clamp(0, pixel_height - 1)
      offset = (row * pixel_width + column) * 4
      [pixels[offset].to_i, pixels[offset + 1].to_i, pixels[offset + 2].to_i, pixels[offset + 3].to_i]
    end

    # The leftmost and rightmost columns, in points, holding dark label ink.
    def label_ink_span : {Float64, Float64}
      leftmost = pixel_width
      rightmost = -1
      pixel_height.times do |row|
        pixel_width.times do |column|
          offset = (row * pixel_width + column) * 4
          next if pixels[offset + 3] < 250
          next unless pixels[offset] < 90 && pixels[offset + 1] < 90 && pixels[offset + 2] < 90
          leftmost = column if column < leftmost
          rightmost = column if column > rightmost
        end
      end
      raise "The capture holds no label ink" if rightmost < 0
      {leftmost / FACE_CAPTURE_SCALE, (rightmost + 1) / FACE_CAPTURE_SCALE}
    end
  end

  private def srgb_bytes(color : UI::Color) : Array(Int32)
    [(color.r * 255).round.to_i, (color.g * 255).round.to_i, (color.b * 255).round.to_i]
  end

  private def assert_face_color(rgba : Array(Int32), color : UI::Color, report : String) : Nil
    rgba[3].should eq(255), report
    srgb_bytes(color).each_with_index do |channel, index|
      (rgba[index] - channel).abs.should be <= FACE_CHANNEL_TOLERANCE, report
    end
  end

  private def faced_button(label : String, &on_tap : -> Nil) : UI::Button
    button = UI::Button.new(label, style: UI::ButtonStyle::Borderless, &on_tap)
    button.font = UI::Font.new(size: 13.0, weight: :semibold)
    button.foreground_color = LABEL_INK
    button.background_fill_color = RESTING_FILL
    button.corner_radius = FACE_CORNER_RADIUS
    button.padding = UI::EdgeInsets.new(leading: 12.0, trailing: 12.0)
    button.minimum_height = FACE_HEIGHT
    button.maximum_height = FACE_HEIGHT
    button.fill_horizontal = true
    button
  end

  private def faced_button(label : String) : UI::Button
    faced_button(label) { }
  end

  private def with_face_window(button : UI::Button, & : Void* ->) : Nil
    native = UI::AppKit::Renderer.new.render(button)
    window = ButtonSurfaceFaceSpecBridge.ap_spec_tracking_window_new(native.handle.ptr!, FACE_WIDTH, FACE_HEIGHT)
    raise "The offscreen window could not be created" if window.null?
    begin
      yield window
      ButtonSurfaceFaceSpecBridge.ap_spec_tracking_application_is_active.should eq(0)
      ButtonSurfaceFaceSpecBridge.ap_spec_tracking_window_is_key(window).should eq(0)
    ensure
      ButtonSurfaceFaceSpecBridge.ap_spec_tracking_window_close(window)
      native.teardown!
    end
  end

  private def capture_face(window : Void*) : FaceCapture
    pixels = Bytes.new(FACE_CAPTURE_CAPACITY)
    size = StaticArray(Int32, 2).new(0)
    captured = ButtonSurfaceFaceSpecBridge.ap_spec_tracking_capture(
      window, FACE_CAPTURE_SCALE, pixels.to_unsafe, FACE_CAPTURE_CAPACITY, size.to_unsafe)
    raise "The button could not be captured" if captured == 0
    FaceCapture.new(pixels, size[0], size[1])
  end

  private def capture_button(button : UI::Button) : FaceCapture
    capture : FaceCapture? = nil
    with_face_window(button) { |window| capture = capture_face(window) }
    capture || raise("The button was not captured")
  end

  # A faced button whose face is a red-to-blue top-down gradient over
  # *base_color*, its reactive background.
  private def gradient_button(base_color : UI::Color?) : UI::Button
    button = faced_button("Save")
    button.background = base_color
    button.background_fill_color = nil
    button.linear_gradient = UI::LinearGradient.new(
      list_of_stops: [
        UI::GradientStop.new(stop_color: UI::Color.new(r: 1.0, g: 0.0, b: 0.0), stop_position: 0.0),
        UI::GradientStop.new(stop_color: UI::Color.new(r: 0.0, g: 0.0, b: 1.0), stop_position: 1.0),
      ],
      gradient_angle: 180.0,
    )
    button
  end

  # A face point clear of the label: inside the leading edge, at mid-height.
  private FACE_SAMPLE_X = 16.0
  private FACE_SAMPLE_Y = FACE_HEIGHT / 2.0

  describe "UI::Button surface face on macOS" do
    it "draws its gradient above its own background, inside the rounded corners" do
      # The pinned facade painted the gradient behind the opaque background,
      # square, so a native button could not carry a designed face.
      over_green = capture_button(gradient_button(BASE_GREEN))
      alone = capture_button(gradient_button(nil))
      top = over_green.rgba_at(FACE_SAMPLE_X, 2.0)
      bottom = over_green.rgba_at(FACE_SAMPLE_X, FACE_HEIGHT - 2.0)
      corner = over_green.rgba_at(0.5, 0.5)
      report = "top #{top}, bottom #{bottom}, corner #{corner}"

      # Red at the top and blue at the bottom, exactly as without the green
      # background under it, and nothing drawn in the rounded-off corner.
      top[0].should be > 200, report
      bottom[2].should be > 200, report
      top.should eq(alone.rgba_at(FACE_SAMPLE_X, 2.0)), report
      bottom.should eq(alone.rgba_at(FACE_SAMPLE_X, FACE_HEIGHT - 2.0)), report
      corner[3].should be < 60, report
    end

    it "centers a filled label by default and leads it when asked" do
      centered = capture_button(faced_button("Enable")).label_ink_span
      leading_button = faced_button("Enable")
      leading_button.text_alignment = UI::Alignment::Leading
      leading = capture_button(leading_button).label_ink_span
      report = "centered #{centered}, leading #{leading}"

      centered_middle = (centered[0] + centered[1]) / 2.0
      (centered_middle - FACE_WIDTH / 2.0).abs.should be <= 1.5, report
      # The leading label starts at the 12 pt inset.
      (leading[0] - 12.0).abs.should be <= 2.0, report
    end

    {
      {"hover", UI::PreviewState::Hover, HOVERED_FILL},
      {"pressed", UI::PreviewState::Pressed, PRESSED_FILL},
    }.each do |phase_name, preview_state, expected_fill|
      it "draws its #{phase_name} face for the #{phase_name} preview state" do
        button = faced_button("Save")
        button.hovered_surface_style = UI::SurfaceStyle.new(background_fill_color: HOVERED_FILL)
        button.pressed_surface_style = UI::SurfaceStyle.new(background_fill_color: PRESSED_FILL)
        resting = capture_button(button).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)

        button.preview_state = preview_state
        forced = capture_button(button).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
        report = "resting #{resting}, #{phase_name} #{forced}"
        assert_face_color(resting, RESTING_FILL, report)
        assert_face_color(forced, expected_fill, report)
      end
    end

    it "tints its resting face when hovered or pressed without a face of its own" do
      button = faced_button("Save")
      resting = capture_button(button).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
      button.preview_state = UI::PreviewState::Pressed
      pressed = capture_button(button).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
      report = "resting #{resting}, pressed #{pressed}"
      assert_face_color(resting, RESTING_FILL, report)
      (pressed[0] + pressed[1] + pressed[2]).should be < resting[0] + resting[1] + resting[2] - 30, report
    end

    it "shows its pressed face while a real mouse press is held and runs its action once on release" do
      taps = 0
      button = faced_button("Save") { taps += 1 }
      button.pressed_surface_style = UI::SurfaceStyle.new(background_fill_color: PRESSED_FILL)
      with_face_window(button) do |window|
        resting = capture_face(window).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
        ButtonSurfaceFaceSpecBridge.ap_spec_tracking_send_mouse(window, FACE_WIDTH / 2.0, FACE_SAMPLE_Y, 1).should eq(1)
        held = capture_face(window).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
        ButtonSurfaceFaceSpecBridge.ap_spec_tracking_send_mouse(window, FACE_WIDTH / 2.0, FACE_SAMPLE_Y, 0).should eq(1)
        released = capture_face(window).rgba_at(FACE_SAMPLE_X, FACE_SAMPLE_Y)
        report = "resting #{resting}, held #{held}, released #{released}, taps #{taps}"

        assert_face_color(resting, RESTING_FILL, report)
        assert_face_color(held, PRESSED_FILL, report)
        assert_face_color(released, RESTING_FILL, report)
        taps.should eq(1), report
      end
    end
  end
{% end %}
