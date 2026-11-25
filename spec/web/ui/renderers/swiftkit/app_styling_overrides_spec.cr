require "../../../spec_helper"
require "../../../../../src/ui"
require "../../../../../src/ui/renderers/web_renderer"

# The styling an app sets on labels, buttons and stacks reaches the native
# SwiftKit overrides (first render) with the values the Swift facades read.
# Native rendering of the same properties is exercised by
# spec/native_macos/native/app_styling_spec.cr.

# Records each setter with the full color, including the dark channels of a
# dynamic color, so a spec can tell a dynamic color from its light half.
private class StylingRecordingSender < UI::Native::Populator::Sender
  getter colors = {} of Symbol => UI::Color
  getter numbers = {} of Symbol => Float64
  getter strings = {} of Symbol => String
  getter bools = {} of Symbol => Bool

  def set_color(target : String, setter : Symbol, color : UI::Color?)
    colors[setter] = color if color
  end

  def set_number(target : String, setter : Symbol, value : Float64?)
    numbers[setter] = value if value
  end

  def set_bool(target : String, setter : Symbol, value : Bool?)
    bools[setter] = value unless value.nil?
  end

  def set_string(target : String, setter : Symbol, value : String?)
    strings[setter] = value if value
  end
end

private def populate_button(view : UI::Button) : StylingRecordingSender
  sender = StylingRecordingSender.new
  UI::Native::Populator.populate_button("button", view, sender)
  sender
end

private def populate_label(view : UI::Label) : StylingRecordingSender
  sender = StylingRecordingSender.new
  UI::Native::Populator.populate_label("label", view, sender)
  sender
end

private def render_web(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

private INK_LIGHT = UI::Color.new(r: 0.1, g: 0.1, b: 0.12)
private INK_DARK  = UI::Color.new(r: 0.94, g: 0.94, b: 0.96)

describe UI::Color do
  describe ".dynamic" do
    it "keeps the light channels as the color and the dark channels in #dark" do
      ink = UI::Color.dynamic(light: INK_LIGHT, dark: INK_DARK)

      ink.r.should eq(0.1)
      ink.b.should eq(0.12)
      ink.dynamic?.should be_true
      ink.dark.should eq(UI::ColorComponents.new(r: 0.94, g: 0.94, b: 0.96, a: 1.0))
    end

    it "resolves to the light or dark color for an appearance" do
      ink = UI::Color.dynamic(light: INK_LIGHT, dark: INK_DARK)

      ink.resolved_for(:light).should eq(INK_LIGHT)
      ink.resolved_for(:dark).should eq(INK_DARK)
      ink.light_appearance.dynamic?.should be_false
    end

    it "leaves a plain color unchanged in both appearances" do
      INK_LIGHT.dynamic?.should be_false
      INK_LIGHT.resolved_for(:dark).should eq(INK_LIGHT)
    end

    it "still builds plain colors positionally" do
      UI::Color.new(0.2, 0.3, 0.4).should eq(UI::Color.new(r: 0.2, g: 0.3, b: 0.4, a: 1.0))
    end
  end

  describe "on the web" do
    it "renders a dynamic color with CSS light-dark()" do
      label = UI::Label.new("Ink")
      label.background = UI::Color.dynamic(light: INK_LIGHT, dark: INK_DARK)

      render_web(label).should contain("light-dark(rgba(26, 26, 31, 1.0), rgba(240, 240, 245, 1.0))")
    end
  end
end

describe UI::Native::Populator, "app styling on buttons" do
  it "sends font size, weight and foreground color on first render" do
    button = UI::Button.new("Join")
    button.font = UI::Font.new(size: 15.0, weight: :semibold)
    button.foreground_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)

    sender = populate_button(button)

    sender.numbers[:setFontSize].should eq(15.0)
    sender.numbers[:setFontWeight].should eq(2.0)
    sender.colors[:setForegroundColor].should eq(UI::Color.new(r: 1.0, g: 1.0, b: 1.0))
  end

  it "sends a named family and the system monospace family" do
    named = UI::Button.new("Join")
    named.font = UI::Font.new(family: "Michroma", size: 13.0)
    populate_button(named).strings[:setFontFamily].should eq("Michroma")

    mono = UI::Button.new("Join")
    mono.font = UI::Font.new(family: "monospace", size: 13.0)
    populate_button(mono).strings[:setFontFamily].should eq("monospace")
  end

  it "sends a dynamic foreground color with its dark channels" do
    button = UI::Button.new("Join")
    button.foreground_color = UI::Color.dynamic(light: INK_LIGHT, dark: INK_DARK)

    sent = populate_button(button).colors[:setForegroundColor]
    sent.dynamic?.should be_true
    sent.dark_appearance.should eq(INK_DARK)
  end

  it "sends a dynamic foreground whose light half is the default system blue" do
    system_blue = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
    button = UI::Button.new("Join")
    button.foreground_color = UI::Color.dynamic(light: system_blue, dark: INK_DARK)

    populate_button(button).colors.has_key?(:setForegroundColor).should be_true
  end

  it "keeps the default button free of font and foreground setters" do
    sender = populate_button(UI::Button.new("Join"))

    sender.numbers.has_key?(:setFontSize).should be_false
    sender.strings.has_key?(:setFontFamily).should be_false
    sender.colors.has_key?(:setForegroundColor).should be_false
  end

  it "stores a font assigned after construction" do
    button = UI::Button.new("Join")
    button.font = UI::Font.new(family: "Courier Prime", size: 20.0, weight: :bold)

    button.font.family.should eq("Courier Prime")
    populate_button(button).numbers[:setFontSize].should eq(20.0)
  end
end

describe UI::Native::Populator, "app styling on labels" do
  it "sends padding and background together, which the facade draws padding-inside-fill" do
    label = UI::Label.new("Pill")
    label.background = UI::Color.new(r: 0.9, g: 0.2, b: 0.2)
    label.padding = UI::EdgeInsets.new(top: 4.0, leading: 10.0, bottom: 4.0, trailing: 10.0)

    sender = populate_label(label)

    sender.colors[:setBackgroundColor].should eq(UI::Color.new(r: 0.9, g: 0.2, b: 0.2))
    sender.numbers[:setPaddingTop].should eq(4.0)
    sender.numbers[:setPaddingLeading].should eq(10.0)
  end

  it "sends the family for a named face and for system monospace" do
    label = UI::Label.new("Code")
    label.font = UI::Font.new(family: "monospace", size: 12.0)
    populate_label(label).strings[:setFontFamily].should eq("monospace")
  end

  it "sends a dynamic text color with its dark channels" do
    label = UI::Label.new("Ink")
    label.text_color = UI::Color.dynamic(light: INK_LIGHT, dark: INK_DARK)

    sent = populate_label(label).colors[:setForegroundColor]
    sent.dark_appearance.should eq(INK_DARK)
  end
end
