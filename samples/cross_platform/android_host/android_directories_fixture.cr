# Private directories contract. The host hands Crystal its files directory
# (durable) and its cache directory (purgeable) as canonical paths; an
# application puts its caches, cookie jars and documents under them instead
# of guessing a home directory. The fixture prints both paths and proves each
# is writable by writing a marker file and reading it back.
module AndroidDirectoriesFixture
  MARKER = "asset_pipeline_directories_fixture.txt"

  def self.build(files_dir : String, cache_dir : String) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "directories-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native directories")
    heading.accessibility_role = :header
    heading.test_id = "directories-heading"
    root << heading
    root << label("directories-files", "Files #{files_dir}")
    root << label("directories-cache", "Cache #{cache_dir}")
    root << label("directories-files-write", "Files write #{round_trip(files_dir)}")
    root << label("directories-cache-write", "Cache write #{round_trip(cache_dir)}")
    root
  end

  # "ok" when a marker written under the directory reads back, else the reason.
  def self.round_trip(dir : String) : String
    path = File.join(dir, MARKER)
    File.write(path, "written by the directories fixture\n")
    File.read(path).starts_with?("written by") ? "ok" : "mismatch"
  rescue error
    error.class.to_s
  end

  private def self.label(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end
end
