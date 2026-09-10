# Real public UI::Image paths, not ImageView instances assembled by the test.
module AndroidImageFixture
  def self.image(source : String, id : String, mode : UI::ContentMode, tinted = false) : UI::Image
    image = UI::Image.new(source)
    image.test_id = id
    image.content_mode = mode
    image.minimum_width = image.maximum_width = 80.0
    image.minimum_height = image.maximum_height = 80.0
    image.tint_color = UI::Color.new(r: 0.0, g: 1.0, b: 0.0) if tinted
    image
  end

  def self.build : UI::View
    stack = UI::VStack.new(4.0, UI::Alignment::Leading)
    stack << image("contract/雪 😀", "image-fit", UI::ContentMode::Fit)
    stack << image("contrast", "image-fill", UI::ContentMode::Fill)
    stack << image("contrast", "image-stretch", UI::ContentMode::Stretch)
    stack << image("contrast", "image-tint", UI::ContentMode::Fit, true)
    stack << image("contrast", "image-untinted", UI::ContentMode::Fit)
    stack << image("raster", "image-raster", UI::ContentMode::Stretch)
    stack << image("jpeg", "image-jpeg", UI::ContentMode::Stretch)
    stack
  end
end
