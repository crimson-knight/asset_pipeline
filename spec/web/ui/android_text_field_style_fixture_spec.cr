require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_text_field_style_fixture"
require "spec"

private def fields_by_id : Hash(String, UI::TextField)
  fields = {} of String => UI::TextField
  AndroidTextFieldStyleFixture.build.as(UI::VStack).children.each do |child|
    if child.is_a?(UI::TextField) && (id = child.test_id)
      fields[id] = child
    end
  end
  fields
end

describe AndroidTextFieldStyleFixture do
  it "shows the three styles with the plain field carrying the brand placeholder color" do
    fields = fields_by_id
    fields["field-rounded"].style.should eq(UI::TextFieldStyle::RoundedBorder)
    fields["field-rounded"].placeholder_color.should be_nil
    fields["field-underline"].style.should eq(UI::TextFieldStyle::Underline)
    fields["field-plain"].style.should eq(UI::TextFieldStyle::Plain)
    fields["field-plain"].placeholder_color.should eq(AndroidTextFieldStyleFixture::PLACEHOLDER_INK)
    fields["field-plain"].placeholder.should eq("Plain, brand placeholder")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidTextFieldStyleFixture.build.as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
    ids.size.should eq(4)
  end
end
