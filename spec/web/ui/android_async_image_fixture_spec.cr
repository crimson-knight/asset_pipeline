require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_async_image_fixture"
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

describe AndroidAsyncImageFixture do
  it "hands the bytes to each image at its content mode and gives the waiting image a placeholder" do
    bytes = Bytes.new(1902) { |i| (i % 251).to_u8 }
    views = views_by_id(AndroidAsyncImageFixture.build(bytes))
    views["async-heading"].as(UI::Label).text.should eq("Native async images")
    views["async-bytes"].as(UI::Label).text.should eq("Bytes 1902")
    {"async-fit" => UI::ContentMode::Fit, "async-fill" => UI::ContentMode::Fill, "async-stretch" => UI::ContentMode::Stretch}.each do |id, mode|
      image = views[id].as(UI::AsyncImage)
      image.preloaded_data.should eq(bytes)
      image.content_mode.should eq(mode)
      image.maximum_width.should eq(96.0)
      image.maximum_height.should eq(64.0)
    end
    waiting = views["async-waiting"].as(UI::AsyncImage)
    waiting.preloaded_data.should be_nil
    waiting.placeholder.as(UI::Label).text.should eq("Loading photo")
  end

  it "carries a large photo and an undecodable image with its own placeholder" do
    photo = Bytes.new(15_000) { |i| (i % 253).to_u8 }
    views = views_by_id(AndroidAsyncImageFixture.build(nil, photo))
    views["async-photo-bytes"].as(UI::Label).text.should eq("Photo 15000")
    views["async-photo"].as(UI::AsyncImage).preloaded_data.should eq(photo)
    views["async-photo"].as(UI::AsyncImage).content_mode.should eq(UI::ContentMode::Fill)
    broken = views["async-broken"].as(UI::AsyncImage)
    broken.preloaded_data.not_nil!.size.should eq(300)
    broken.placeholder.as(UI::Label).text.should eq("Photo unavailable")
  end

  it "shows zero bytes when nothing was prefetched" do
    views_by_id(AndroidAsyncImageFixture.build(nil))["async-bytes"].as(UI::Label).text.should eq("Bytes 0")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidAsyncImageFixture.build(nil).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end
