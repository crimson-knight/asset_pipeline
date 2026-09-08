require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_button_fixture"
require "spec"

private def buttons_by_id : Hash(String, UI::Button)
  buttons = {} of String => UI::Button
  AndroidButtonFixture.build.as(UI::VStack).children.each do |child|
    if child.is_a?(UI::Button) && (id = child.test_id)
      buttons[id] = child
    end
  end
  buttons
end

describe AndroidButtonFixture do
  it "gives the brand button explicit colors, the outlined one a border, and leaves the default button alone" do
    buttons = buttons_by_id
    brand = buttons["button-brand"]
    brand.background.should eq(AndroidButtonFixture::BRAND_RED)
    brand.foreground_color.should eq(AndroidButtonFixture::WHITE)
    brand.style.should eq(UI::ButtonStyle::Prominent)
    default = buttons["button-default"]
    default.background.should be_nil
    default.foreground_color.should eq(UI::Button.new("x").foreground_color)
    default.border_width.should eq(0.0)
    outlined = buttons["button-outlined"]
    outlined.border_width.should eq(1.0)
    outlined.border_color.should eq(AndroidButtonFixture::INK)
    outlined.foreground_color.should eq(AndroidButtonFixture::INK)
  end

  it "caps the lines and aligns the labels the way the device test expects" do
    buttons = buttons_by_id
    buttons["button-wrap"].number_of_lines.should eq(0)
    buttons["button-wrap"].maximum_width.should eq(200.0)
    buttons["button-capped"].number_of_lines.should eq(2)
    buttons["button-leading"].text_alignment.should eq(UI::Alignment::Leading)
    buttons["button-trailing"].text_alignment.should eq(UI::Alignment::Trailing)
    buttons["button-default"].text_alignment.should eq(UI::Alignment::Center)
    buttons["button-default"].number_of_lines.should eq(1)
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidButtonFixture.build.as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
    ids.size.should eq(8)
  end
end
