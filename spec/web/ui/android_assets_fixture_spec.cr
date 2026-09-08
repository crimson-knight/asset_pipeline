require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_assets_fixture"
require "spec"

private def views_by_id(view : UI::View) : Hash(String, UI::View)
  views = {} of String => UI::View
  view.as(UI::VStack).children.each do |child|
    if id = child.test_id
      views[id] = child
    end
  end
  views
end

describe AndroidAssetsFixture do
  it "loads the mark by path, reads the note and names the faces" do
    dir = File.join(Dir.tempdir, "ap-assets-fixture-#{Process.pid}")
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "note.txt"), "The bundle is real files.\nsecond line\n")
    begin
      views = views_by_id(AndroidAssetsFixture.build(dir, 1))
      views["assets-heading"].as(UI::Label).text.should eq("Native assets")
      views["assets-bundle"].as(UI::Label).text.should eq("Bundle #{dir}")
      views["assets-fonts"].as(UI::Label).text.should eq("Fonts 1")
      views["assets-mark"].as(UI::Image).source.should eq(File.join(dir, "art/mark@2x.png"))
      views["assets-note"].as(UI::Label).text.should eq("Note The bundle is real files.")
      views["assets-inter"].as(UI::Label).font.family.should eq("Inter-SemiBold")
      views["assets-serif"].as(UI::Label).font.family.should eq("serif")
      views["assets-system"].as(UI::Label).font.family.should eq("system")
      views["assets-unknown"].as(UI::Label).font.family.should eq("NoSuchFace-Bold")
    ensure
      File.delete(File.join(dir, "note.txt"))
      Dir.delete(dir)
    end
  end

  it "says so when the host extracted no bundle" do
    views = views_by_id(AndroidAssetsFixture.build(nil, 0))
    views["assets-bundle"].as(UI::Label).text.should eq("Bundle none")
    views["assets-fonts"].as(UI::Label).text.should eq("Fonts 0")
    views.has_key?("assets-mark").should be_false
    views.has_key?("assets-note").should be_false
  end

  it "reports a missing note instead of raising" do
    AndroidAssetsFixture.note("/nonexistent/bundle").should eq("missing")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidAssetsFixture.build("/tmp/none", 0).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end
