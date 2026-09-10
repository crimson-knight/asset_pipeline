require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_photo_fixture"
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

describe AndroidPhotoFixture do
  it "prints the picker's state and result and wires one button per action" do
    taps = [] of String
    snapshot = AndroidPhotoFixture::Snapshot.new("Ready", 243_117, 2000, 1333, true, false, "none")
    views = views_by_id(AndroidPhotoFixture.build(snapshot, -> { taps << "library"; nil }, -> { taps << "camera"; nil }, -> { taps << "reset"; nil }))
    views["photo-heading"].as(UI::Label).text.should eq("Native photos")
    views["photo-state"].as(UI::Label).text.should eq("State Ready")
    views["photo-bytes"].as(UI::Label).text.should eq("Bytes 243117")
    views["photo-size"].as(UI::Label).text.should eq("Size 2000x1333")
    views["photo-available"].as(UI::Label).text.should eq("Library true camera false")
    views["photo-error"].as(UI::Label).text.should eq("Error none")
    views["photo-library"].as(UI::Button).on_tap.not_nil!.call
    views["photo-camera"].as(UI::Button).on_tap.not_nil!.call
    views["photo-reset"].as(UI::Button).on_tap.not_nil!.call
    taps.should eq(["library", "camera", "reset"])
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    snapshot = AndroidPhotoFixture::Snapshot.new("Idle", 0, 0, 0, false, false, "none")
    none = -> { nil }
    ids = AndroidPhotoFixture.build(snapshot, none, none, none).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end
