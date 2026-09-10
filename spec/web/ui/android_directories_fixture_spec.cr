require "../../../src/ui"
require "../../../samples/cross_platform/android_host/android_directories_fixture"
require "spec"

private def labels(view : UI::View) : Hash(String, String)
  labels = {} of String => String
  view.as(UI::VStack).children.each do |child|
    if (label = child.as?(UI::Label)) && (id = label.test_id)
      labels[id] = label.text
    end
  end
  labels
end

describe AndroidDirectoriesFixture do
  it "prints both directories and proves each is writable" do
    files = File.join(Dir.tempdir, "ap-directories-files-#{Process.pid}")
    cache = File.join(Dir.tempdir, "ap-directories-cache-#{Process.pid}")
    Dir.mkdir_p(files)
    Dir.mkdir_p(cache)
    begin
      texts = labels(AndroidDirectoriesFixture.build(files, cache))
      texts["directories-heading"].should eq("Native directories")
      texts["directories-files"].should eq("Files #{files}")
      texts["directories-cache"].should eq("Cache #{cache}")
      texts["directories-files-write"].should eq("Files write ok")
      texts["directories-cache-write"].should eq("Cache write ok")
      File.exists?(File.join(files, AndroidDirectoriesFixture::MARKER)).should be_true
    ensure
      [files, cache].each do |dir|
        File.delete(File.join(dir, AndroidDirectoriesFixture::MARKER)) if File.exists?(File.join(dir, AndroidDirectoriesFixture::MARKER))
        Dir.delete(dir)
      end
    end
  end

  it "names the failure instead of raising when a directory cannot be written" do
    AndroidDirectoriesFixture.round_trip("/nonexistent/asset-pipeline").should eq("File::NotFoundError")
  end

  it "keeps every identifier unique so native assertions cannot select a different view" do
    ids = AndroidDirectoriesFixture.build(Dir.tempdir, Dir.tempdir).as(UI::VStack).children.compact_map(&.test_id)
    ids.size.should eq(ids.uniq.size)
  end
end
