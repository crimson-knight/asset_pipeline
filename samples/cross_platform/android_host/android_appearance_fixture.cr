# Appearance contract. The host says whether it is drawing in the dark, the way
# an iOS host's trait collection does, and a brand theme picks its dark or
# light identity from that before a render. The fixture prints the answer.
module AndroidAppearanceFixture
  def self.build(dark : Bool) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "appearance-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native appearance")
    heading.accessibility_role = :header
    heading.test_id = "appearance-heading"
    root << heading
    answer = UI::Label.new("Appearance #{dark ? "dark" : "light"}")
    answer.test_id = "appearance-answer"
    root << answer
    root
  end
end
