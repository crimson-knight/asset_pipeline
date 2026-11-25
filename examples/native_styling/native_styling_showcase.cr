# Native macOS styling showcase.
#
# Renders one screen of the styling an app sets on native views — button
# font and foreground, padding inside a fill, named / monospace / missing
# font families, rounded bordered shadowed stacks, HStack top and bottom
# padding, and dynamic light/dark colors — through UI::AppKit::Renderer, then
# writes an offscreen render of it in the light and the dark appearance.
#
# Build and run with the Makefile beside this file:
#
#   make -C examples/native_styling run OUT=/tmp/native-styling \
#        MICHROMA=/path/to/Michroma-Regular.ttf
#
# Writes OUT/native-styling-light.png and OUT/native-styling-dark.png. The
# Michroma face is optional; without it that row shows the system fallback.

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
    end
  end
end

NativeStylingShowcase.run(ENV["OUT"]? || "output/native-styling", ENV["MICHROMA"]?)
