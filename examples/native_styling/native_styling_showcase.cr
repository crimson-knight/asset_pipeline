# Native macOS styling showcase.
#
# Renders one screen of the styling an app sets on native views — button
# font and foreground, padding inside a fill, named / monospace / missing
# font families, rounded bordered shadowed stacks, HStack top and bottom
# padding, dynamic light/dark colors, dynamic shape fills, a bordered
# app-styled button, rotation, stack gradients with grain, and columns in a
# top-aligned row — through UI::AppKit::Renderer, then writes an offscreen
# render of it in the light and the dark appearance.
#
# Build and run with the Makefile beside this file:
#
#   make -C examples/native_styling run OUT=/tmp/native-styling \
#        MICHROMA=/path/to/Michroma-Regular.ttf
#
# Writes OUT/native-styling-light.png and OUT/native-styling-dark.png, plus
# OUT/native-styling-button-<state>-<appearance>.png for a bordered button in
# its resting, hover, pressed and focused states. The Michroma face is
# optional; without it that row shows the system fallback.

require "../../src/ui"

{% unless flag?(:macos) %}
  {% raise "examples/native_styling runs on macOS only (build with -Dmacos)" %}
{% end %}

module NativeStylingShowcase
  alias Bridge = UI::AppKit::LibObjCBridge

  PAGE      = UI::Color.dynamic(light: UI::Color.new(r: 0.97, g: 0.96, b: 0.93), dark: UI::Color.new(r: 0.09, g: 0.09, b: 0.11))
  CARD      = UI::Color.dynamic(light: UI::Color.new(r: 1.0, g: 1.0, b: 1.0), dark: UI::Color.new(r: 0.16, g: 0.16, b: 0.19))
  INK       = UI::Color.dynamic(light: UI::Color.new(r: 0.11, g: 0.11, b: 0.13), dark: UI::Color.new(r: 0.93, g: 0.93, b: 0.95))
  MUTED_INK = UI::Color.dynamic(light: UI::Color.new(r: 0.38, g: 0.37, b: 0.35), dark: UI::Color.new(r: 0.66, g: 0.66, b: 0.70))
  BRAND     = UI::Color.dynamic(light: UI::Color.new(r: 0.73, g: 0.33, b: 0.11), dark: UI::Color.new(r: 0.96, g: 0.62, b: 0.27))
  RULE      = UI::Color.dynamic(light: UI::Color.new(r: 0.85, g: 0.83, b: 0.79), dark: UI::Color.new(r: 0.30, g: 0.30, b: 0.34))
  PILL_FILL = UI::Color.dynamic(light: UI::Color.new(r: 0.99, g: 0.90, b: 0.80), dark: UI::Color.new(r: 0.33, g: 0.21, b: 0.11))
  SHADOW    = UI::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.18)

  def self.caption(text : String) : UI::Label
    label = UI::Label.new(text)
    label.font = UI::Font.new(family: "monospace", size: 11.0, weight: :medium)
    label.text_color = MUTED_INK
    label
  end

  def self.body(text : String, font : UI::Font) : UI::Label
    label = UI::Label.new(text)
    label.font = font
    label.text_color = INK
    label
  end

  def self.card(title : String, &) : UI::VStack
    card = UI::VStack.new(spacing: 10.0, alignment: UI::Alignment::Leading)
    card.background = CARD
    card.corner_radius = 14.0
    card.border_width = 1.0
    card.border_color = RULE
    card.shadow_radius = 10.0
    card.shadow_offset_y = 4.0
    card.shadow_color = SHADOW
    card.padding = UI::EdgeInsets.new(top: 16.0, leading: 18.0, bottom: 16.0, trailing: 18.0)
    card << caption(title)
    yield card
    card
  end

  def self.bordered_button : UI::Button
    button = UI::Button.new("Open the story")
    button.font = UI::Font.new(size: 14.0, weight: :semibold)
    button.foreground_color = BRAND
    button.background = PILL_FILL
    button.corner_radius = 16.0
    button.border_width = 1.5
    button.border_color = BRAND
    button.padding = UI::EdgeInsets.new(top: 8.0, leading: 16.0, bottom: 8.0, trailing: 16.0)
    button
  end

  # A rubber-stamp label, tilted like the Drafting Room story stamp.
  def self.story_stamp(text : String, rotation_degrees : Float64) : UI::Label
    stamp = UI::Label.new(text)
    stamp.font = UI::Font.new(family: "monospace", size: 12.0, weight: :bold)
    stamp.text_color = BRAND
    stamp.background = PILL_FILL
    stamp.corner_radius = 4.0
    stamp.padding = UI::EdgeInsets.new(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0)
    stamp.rotation_degrees = rotation_degrees
    stamp
  end

  def self.gradient_swatch(gradient : UI::BackgroundGradient) : UI::VStack
    swatch = UI::VStack.new(alignment: UI::Alignment::Leading)
    swatch.minimum_width = 220.0
    swatch.maximum_width = 220.0
    swatch.minimum_height = 110.0
    swatch.corner_radius = 12.0
    swatch.padding = UI::EdgeInsets.new(top: 10.0, leading: 12.0, bottom: 10.0, trailing: 12.0)
    swatch.background_gradient = gradient
    swatch
  end

  # A card-colored column of `line_count` short lines.
  def self.column_of_lines(line_count : Int32) : UI::VStack
    column = UI::VStack.new(spacing: 4.0, alignment: UI::Alignment::Leading)
    column.background = CARD
    column.corner_radius = 6.0
    column.padding = UI::EdgeInsets.new(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0)
    line_count.times do |line_index|
      column << body("line #{line_index + 1}", UI::Font.new(size: 12.0))
    end
    column
  end

  def self.screen : UI::View
    root = UI::VStack.new(spacing: 18.0, alignment: UI::Alignment::Leading)
    root.background = PAGE
    root.padding = UI::EdgeInsets.new(top: 28.0, leading: 28.0, bottom: 28.0, trailing: 28.0)

    root << body("Drafting Room", UI::Font.new(family: "Michroma", size: 22.0))

    root << card("1  BUTTON FONT + FOREGROUND") { |card|
      join = UI::Button.new("Join the room")
      join.font = UI::Font.new(size: 15.0, weight: :semibold)
      join.foreground_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
      join.background = BRAND
      join.corner_radius = 10.0
      join.padding = UI::EdgeInsets.new(top: 10.0, leading: 18.0, bottom: 10.0, trailing: 18.0)
      card << join
    }

    root << card("2  PADDING INSIDE THE FILL") { |card|
      pill = UI::Label.new("Draft · 3 stories")
      pill.font = UI::Font.new(size: 12.0, weight: :semibold)
      pill.text_color = BRAND
      pill.background = PILL_FILL
      pill.corner_radius = 11.0
      pill.padding = UI::EdgeInsets.new(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0)
      card << pill
    }

    root << card("3  FONT FAMILIES") { |card|
      card << body("Michroma — the brand display face", UI::Font.new(family: "Michroma", size: 14.0))
      card << body("Courier Prime — a named family", UI::Font.new(family: "Courier Prime", size: 14.0))
      card << body("NotInstalled-Bold — missing, so the system face", UI::Font.new(family: "NotInstalled-Bold", size: 14.0, weight: :bold))
      card << body("System monospace — 0123456789", UI::Font.new(family: "monospace", size: 14.0))
      card << body("System — the default face", UI::Font.new(size: 14.0))
    }

    root << card("4  STACK RADIUS, BORDER, SHADOW") { |card|
      card << body("This card is a VStack: 14pt corners, a 1pt rule, a soft shadow.", UI::Font.new(size: 13.0))
    }

    root << card("5  HSTACK TOP + BOTTOM PADDING") { |card|
      row = UI::HStack.new(spacing: 8.0)
      row.background = PILL_FILL
      row.corner_radius = 8.0
      row.padding = UI::EdgeInsets.new(top: 14.0, leading: 12.0, bottom: 14.0, trailing: 12.0)
      row << body("14pt above and below this row", UI::Font.new(size: 13.0))
      card << row
    }

    root << card("6  DYNAMIC COLORS") { |card|
      card << body("Page, card, ink, brand and rule colors resolve per appearance.", UI::Font.new(size: 13.0))
    }

    root << card("7  SHAPES WITH A DYNAMIC FILL") { |card|
      row = UI::HStack.new(spacing: 12.0)
      square = UI::Rectangle.new(width: 44.0, height: 44.0)
      square.fill_color = BRAND
      rounded = UI::RoundedRectangle.new(corner_radius: 10.0, width: 44.0, height: 44.0)
      rounded.fill_color = PILL_FILL
      rounded.stroke_color = BRAND
      rounded.stroke_width = 2.0
      dot = UI::Circle.new(size: 44.0)
      dot.fill_color = INK
      row << square << rounded << dot
      card << row
    }

    root << card("8  APP-STYLED BUTTON WITH A BORDER") { |card|
      card << bordered_button
    }

    root << card("9  ROTATION ABOUT THE CENTER") { |card|
      row = UI::HStack.new(spacing: 18.0)
      row.padding = UI::EdgeInsets.new(top: 6.0, leading: 8.0, bottom: 6.0, trailing: 8.0)
      row << story_stamp("DRAFT", -6.0) << story_stamp("IN REVIEW", 4.0)
      card << row
    }

    root << card("10  STACK GRADIENTS + GRAIN") { |card|
      row = UI::HStack.new(spacing: 12.0)
      linear = gradient_swatch(UI::BackgroundGradient.linear([
        UI::GradientStop.new(color: PILL_FILL, location: 0.0),
        UI::GradientStop.new(color: BRAND, location: 1.0),
      ], from: UI::UnitPoint::TOP_LEADING, to: UI::UnitPoint::BOTTOM_TRAILING))
      linear << body("linear", UI::Font.new(size: 12.0, weight: :semibold))
      radial = gradient_swatch(UI::BackgroundGradient.radial([
        UI::GradientStop.new(color: CARD, location: 0.0),
        UI::GradientStop.new(color: PILL_FILL, location: 0.55),
        UI::GradientStop.new(color: BRAND, location: 1.0),
      ], radius_fraction: 0.75))
      radial.grain_opacity = 0.12
      radial << body("radial + grain", UI::Font.new(size: 12.0, weight: :semibold))
      row << linear << radial
      card << row
    }

    root << card("11  COLUMNS IN A TOP-ALIGNED ROW") { |card|
      row = UI::HStack.new(spacing: 10.0, alignment: UI::Alignment::Top)
      row.padding = UI::EdgeInsets.new(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
      row.background = PILL_FILL
      row.corner_radius = 8.0
      # The empty column keeps its own (padding-only) height instead of
      # stretching to the row's height.
      empty_column = column_of_lines(0)
      empty_column.minimum_width = 40.0
      row << column_of_lines(1) << column_of_lines(3) << empty_column
      card << row
    }

    root
  end

  def self.run(output_dir : String, michroma_path : String?) : Nil
    Dir.mkdir_p(output_dir)
    # SwiftUI hosting views need the shared application object.
    app_class = Bridge.objc_getClass("NSApplication")
    Bridge.objc_send(app_class, Bridge.sel_registerName("sharedApplication"))

    if path = michroma_path
      registered = LibSwiftKitBridge.apsk_register_font(path)
      STDERR.puts "Michroma #{registered ? "registered" : "NOT registered"} from #{path}"
    end

    {"light", "dark"}.each do |appearance|
      native = UI::AppKit::Renderer.new.render(screen)
      png_path = File.join(output_dir, "native-styling-#{appearance}.png")
      snapshot = Bridge.ap_snapshot_view(native.handle.ptr!, appearance, 560.0, 0.0, png_path)
      raise "offscreen render failed for #{appearance}" if snapshot.null?
      Bridge.ap_snapshot_release(snapshot)
      STDOUT.puts "wrote #{png_path}"

      {"none", "hover", "pressed", "focused"}.each do |interaction_state|
        write_button_in_state(output_dir, appearance, interaction_state)
      end
    end
  end

  # A bordered button on a page swatch, drawn in one interaction state.
  def self.write_button_in_state(output_dir : String, appearance : String, interaction_state : String) : Nil
    swatch = UI::HStack.new
    swatch.background = PAGE
    swatch.padding = UI::EdgeInsets.new(top: 14.0, leading: 14.0, bottom: 14.0, trailing: 14.0)
    swatch << bordered_button
    native = UI::AppKit::Renderer.new.render(swatch)
    state_name = interaction_state == "none" ? "resting" : interaction_state
    png_path = File.join(output_dir, "native-styling-button-#{state_name}-#{appearance}.png")
    snapshot = Bridge.ap_snapshot_view_in_interaction_state(native.handle.ptr!, appearance, 0.0, 0.0,
      png_path, interaction_state)
    raise "offscreen render failed for #{state_name} #{appearance}" if snapshot.null?
    Bridge.ap_snapshot_release(snapshot)
    STDOUT.puts "wrote #{png_path}"
  end
end

NativeStylingShowcase.run(ENV["OUT"]? || "output/native-styling", ENV["MICHROMA"]?)
