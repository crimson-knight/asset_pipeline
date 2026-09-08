# AsyncImage contract. The Android renderer has no network loader, and the
# applications that use AsyncImage prefetch their photos and hand the bytes
# over as preloaded_data (the way the AgentC shell does for a customer
# document's product photos), so the reads that matter are the preloaded
# bytes, the content mode and the placeholder shown while nothing has
# loaded. The fixture shows one image from bytes at each content mode and
# one with no bytes and a placeholder label; a device test checks the
# drawables' pixel sizes, the scale types and the placeholder.
module AndroidAsyncImageFixture
  def self.build(bytes : Bytes?) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "async-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native async images")
    heading.accessibility_role = :header
    heading.test_id = "async-heading"
    root << heading
    root << label("async-bytes", "Bytes #{bytes.try(&.size) || 0}")
    root << image("async-fit", bytes, UI::ContentMode::Fit)
    root << image("async-fill", bytes, UI::ContentMode::Fill)
    root << image("async-stretch", bytes, UI::ContentMode::Stretch)
    waiting = UI::AsyncImage.new("https://example.invalid/never-loaded.png")
    waiting.test_id = "async-waiting"
    placeholder = UI::Label.new("Loading photo")
    placeholder.test_id = "async-placeholder"
    waiting.placeholder = placeholder
    waiting.minimum_width = waiting.maximum_width = 96.0
    waiting.minimum_height = waiting.maximum_height = 64.0
    root << waiting
    root
  end

  private def self.label(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end

  # A photo from bytes in a fixed 96 by 64 dp frame, the way a product photo sits in a card.
  private def self.image(id : String, bytes : Bytes?, mode : UI::ContentMode) : UI::AsyncImage
    image = UI::AsyncImage.new("https://example.invalid/#{id}.png")
    image.test_id = id
    image.preloaded_data = bytes
    image.content_mode = mode
    image.minimum_width = image.maximum_width = 96.0
    image.minimum_height = image.maximum_height = 64.0
    image
  end
end
