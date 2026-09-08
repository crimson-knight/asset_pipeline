# Host settings contract. A host application bakes settings into its build
# (an iOS archive writes them to Info.plist, an Android release step to the
# APK's host_settings resource) and registers them with the runtime before
# the first render; Crystal reads one by key through
# UI::Android::Application.setting and gets nil for a key the build does not
# carry. The fixture prints two registered values and one absent key.
module AndroidSettingsFixture
  def self.build(display_name : String?, demo_id : String?, absent : String?) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "settings-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native host settings")
    heading.accessibility_role = :header
    heading.test_id = "settings-heading"
    root << heading
    root << label("settings-name", "Name #{display_name || "absent"}")
    root << label("settings-id", "Id #{demo_id || "absent"}")
    root << label("settings-missing", "Missing #{absent || "absent"}")
    root
  end

  private def self.label(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end
end
