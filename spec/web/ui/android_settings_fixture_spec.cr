require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_settings_fixture"
require "spec"

private def texts(display_name : String?, demo_id : String?, absent : String?) : Hash(String, String)
  out = {} of String => String
  AndroidSettingsFixture.build(display_name, demo_id, absent).as(UI::VStack).children.each do |child|
    if child.is_a?(UI::Label) && (id = child.test_id)
      out[id] = child.text
    end
  end
  out
end

describe AndroidSettingsFixture do
  it "prints the registered values under their labels" do
    labels = texts("Native Host", "SAMPLE01", nil)
    labels["settings-heading"].should eq("Native host settings")
    labels["settings-name"].should eq("Name Native Host")
    labels["settings-id"].should eq("Id SAMPLE01")
    labels["settings-missing"].should eq("Missing absent")
  end

  it "prints absent for every key the build does not carry" do
    labels = texts(nil, nil, nil)
    labels["settings-name"].should eq("Name absent")
    labels["settings-id"].should eq("Id absent")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidSettingsFixture.build(nil, nil, nil).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
    ids.size.should eq(4)
  end
end
