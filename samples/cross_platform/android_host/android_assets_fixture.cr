# Bundled assets contract. The host extracts the APK's bundle into the
# application's private files directory once per install and tells Crystal
# where it is; an application loads art from that tree by file path (the
# iOS contract) and registers the TTFs it finds there under the family names
# its views use. The fixture prints the bundle path and the registered font
# count, shows the bundle's mark loaded by path, reads a note file from it,
# and sets four labels in a registered face, a generic Android family, the
# system face and an unknown name, so a device test can check each one.
module AndroidAssetsFixture
  MARK = "art/mark@2x.png"
  NOTE = "note.txt"

  def self.build(bundle_dir : String?, fonts : Int32) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "assets-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native assets")
    heading.accessibility_role = :header
    heading.test_id = "assets-heading"
    root << heading
    root << label("assets-bundle", "Bundle #{bundle_dir || "none"}")
    root << label("assets-fonts", "Fonts #{fonts}")
    if dir = bundle_dir
      mark = UI::Image.new(File.join(dir, MARK))
      mark.test_id = "assets-mark"
      mark.content_mode = UI::ContentMode::Fit
      root << mark
      root << label("assets-note", "Note #{note(dir)}")
    end
    root << face("assets-inter", "Registered face", "Inter-SemiBold")
    root << face("assets-serif", "Generic serif", "serif")
    root << face("assets-system", "System face", "system")
    root << face("assets-unknown", "Unknown face", "NoSuchFace-Bold")
    root
  end

  # The note's first line, or the reason it could not be read.
  def self.note(dir : String) : String
    path = File.join(dir, NOTE)
    return "missing" unless File.file?(path)
    File.read(path).lines.first?.try(&.strip) || "empty"
  rescue
    "unreadable"
  end

  private def self.label(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end

  private def self.face(id : String, text : String, family : String) : UI::Label
    label = label(id, text)
    label.font = UI::Font.new(family: family, size: 20.0)
    label
  end
end
