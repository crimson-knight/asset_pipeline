require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

# Helper to render a view and return the HTML string
private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe UI::Web::Renderer do
  describe "theme injection" do
    it "injects Amber token CSS variables with dark overrides" do
      renderer = UI::Web::Renderer.new
      css = renderer.inject_theme_css

      css.should contain("--amber-color-brand-primary:")
      css.should contain("@media (prefers-color-scheme: dark)")
      css.should contain("[data-ap-theme=\"light\"]")
      css.should contain("[data-ap-theme=\"dark\"]")
      css.should contain("[data-amber-theme=\"light\"]")
      css.should contain("[data-amber-theme=\"dark\"]")
      css.should contain("--md-sys-color-primary:")
    end
  end

  describe "Label" do
    it "renders to <span> with text content" do
      label = UI::Label.new("Hello World")
      html = render(label)
      html.should contain("<span")
      html.should contain("</span>")
      html.should contain("Hello World")
    end

    it "applies font-size from font property" do
      label = UI::Label.new("Sized")
      label.font = UI::Font.new(size: 24.0)
      html = render(label)
      html.should contain("font-size: 24.0px")
    end

    it "applies custom font family" do
      label = UI::Label.new("Styled")
      label.font = UI::Font.new(family: "Helvetica", size: 14.0)
      html = render(label)
      html.should contain("font-family: Helvetica")
      html.should contain("font-size: 14.0px")
    end

    it "applies bold font weight" do
      label = UI::Label.new("Bold")
      label.font = UI::Font.new(weight: :bold)
      html = render(label)
      html.should contain("font-weight: bold")
    end

    it "applies italic font style" do
      label = UI::Label.new("Italic")
      label.font = UI::Font.new(italic: true)
      html = render(label)
      html.should contain("font-style: italic")
    end

    it "applies text color as rgba" do
      label = UI::Label.new("Red")
      label.text_color_role = nil
      label.text_color = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
      html = render(label)
      html.should contain("color: rgba(255, 0, 0, 1.0)")
    end

    it "maps semantic label roles to Amber text tokens" do
      label = UI::Label.new("Secondary")
      label.text_color_role = UI::LabelRole::Secondary
      html = render(label)

      html.should contain("color: var(--amber-color-text-secondary)")
    end

    it "applies text alignment" do
      label = UI::Label.new("Centered")
      label.text_alignment = UI::Alignment::Center
      html = render(label)
      html.should contain("text-align: center")
    end

    it "applies leading text alignment as left" do
      label = UI::Label.new("Left")
      label.text_alignment = UI::Alignment::Leading
      html = render(label)
      html.should contain("text-align: left")
    end

    it "applies trailing text alignment as right" do
      label = UI::Label.new("Right")
      label.text_alignment = UI::Alignment::Trailing
      html = render(label)
      html.should contain("text-align: right")
    end

    it "applies line clamping when number_of_lines > 0" do
      label = UI::Label.new("Clamped")
      label.number_of_lines = 2
      html = render(label)
      html.should contain("-webkit-line-clamp: 2")
    end

    it "does not apply line clamping when number_of_lines is 0" do
      label = UI::Label.new("Unclamped")
      html = render(label)
      html.should_not contain("-webkit-line-clamp")
    end
  end

  describe "Button" do
    it "renders to <button> with type=button" do
      button = UI::Button.new("Click Me")
      html = render(button)
      html.should contain("<button")
      html.should contain("</button>")
      html.should contain("type=\"button\"")
      html.should contain("Click Me")
      html.should contain("class=\"am-button am-button--brand am-button--outline am-button--md\"")
      html.should contain("data-state=\"default\"")
    end

    it "applies foreground color" do
      button = UI::Button.new("Colored")
      button.foreground_color = UI::Color.new(r: 0.0, g: 1.0, b: 0.0)
      html = render(button)
      html.should contain("color: rgba(0, 255, 0, 1.0)")
    end

    it "applies disabled attribute" do
      button = UI::Button.new("Disabled")
      button.disabled = true
      html = render(button)
      html.should contain("disabled=\"disabled\"")
      html.should contain("data-state=\"disabled\"")
    end

    it "adds data-action attribute when on_tap is set" do
      button = UI::Button.new("Action") { nil }
      html = render(button)
      html.should contain("data-action=\"click\"")
    end

    it "does not add data-action when on_tap is nil" do
      button = UI::Button.new("NoAction")
      html = render(button)
      html.should_not contain("data-action")
    end

    it "applies font styles" do
      button = UI::Button.new("Styled")
      button.font = UI::Font.new(size: 20.0, weight: :bold)
      html = render(button)
      html.should contain("font-size: 20.0px")
      html.should contain("font-weight: bold")
    end

    it "maps destructive prominent buttons to token-backed classes" do
      button = UI::Button.new("Delete", role: :destructive, style: UI::ButtonStyle::Prominent)
      html = render(button)

      html.should contain("am-button--danger")
      html.should contain("am-button--solid")
      html.should contain("data-tone=\"danger\"")
    end
  end

  describe "VStack" do
    it "renders to <div> with flex-direction: column" do
      stack = UI::VStack.new
      html = render(stack)
      html.should contain("<div")
      html.should contain("</div>")
      html.should contain("display: flex")
      html.should contain("flex-direction: column")
    end

    it "applies gap from spacing property" do
      stack = UI::VStack.new(spacing: 16.0)
      html = render(stack)
      html.should contain("gap: 16.0px")
    end

    it "applies default spacing of 8px" do
      stack = UI::VStack.new
      html = render(stack)
      html.should contain("gap: 8.0px")
    end

    it "renders children inside the div" do
      stack = UI::VStack.new
      stack << UI::Label.new("First")
      stack << UI::Label.new("Second")
      html = render(stack)
      html.should contain("<span")
      html.should contain("First")
      html.should contain("Second")
    end

    it "applies align-items: center by default" do
      stack = UI::VStack.new
      html = render(stack)
      html.should contain("align-items: center")
    end

    it "applies align-items: flex-start for Leading alignment" do
      stack = UI::VStack.new(alignment: UI::Alignment::Leading)
      html = render(stack)
      html.should contain("align-items: flex-start")
    end

    it "applies align-items: stretch for Fill alignment" do
      stack = UI::VStack.new(alignment: UI::Alignment::Fill)
      html = render(stack)
      html.should contain("align-items: stretch")
    end
  end

  describe "HStack" do
    it "renders to <div> with flex-direction: row" do
      stack = UI::HStack.new
      html = render(stack)
      html.should contain("<div")
      html.should contain("display: flex")
      html.should contain("flex-direction: row")
    end

    it "applies gap from spacing property" do
      stack = UI::HStack.new(spacing: 12.0)
      html = render(stack)
      html.should contain("gap: 12.0px")
    end

    it "renders children inside the div" do
      stack = UI::HStack.new
      stack << UI::Button.new("A")
      stack << UI::Button.new("B")
      html = render(stack)
      html.should contain("A")
      html.should contain("B")
    end

    it "applies align-items from alignment" do
      stack = UI::HStack.new(alignment: UI::Alignment::Top)
      html = render(stack)
      html.should contain("align-items: flex-start")
    end
  end

  describe "ZStack" do
    it "renders to <div> with position: relative" do
      stack = UI::ZStack.new
      html = render(stack)
      html.should contain("<div")
      html.should contain("position: relative")
    end

    it "applies position: absolute to overlay children (index > 0)" do
      stack = UI::ZStack.new
      stack << UI::Label.new("Base")
      stack << UI::Label.new("Overlay")
      html = render(stack)
      html.should contain("position: relative")
      html.should contain("position: absolute")
    end

    it "does not apply position: absolute to the first child" do
      stack = UI::ZStack.new
      stack << UI::Label.new("Base Only")
      html = render(stack)
      # The outer div has position: relative, but the single child
      # should not have position: absolute
      html.should contain("position: relative")
      # Count occurrences - should only be the parent's relative, no absolute
      html.scan(/position: absolute/).size.should eq(0)
    end
  end

  describe "Image" do
    it "renders to <img> with src and alt" do
      image = UI::Image.new("photo.jpg")
      html = render(image)
      html.should contain("<img")
      html.should contain("src=\"photo.jpg\"")
      html.should contain("alt=\"photo.jpg\"")
    end

    it "uses accessibility_label as alt text when set" do
      image = UI::Image.new("icon.png")
      image.accessibility_label = "Star icon"
      html = render(image)
      html.should contain("alt=\"Star icon\"")
    end

    it "applies object-fit: contain for Fit content mode" do
      image = UI::Image.new("photo.jpg")
      image.content_mode = UI::ContentMode::Fit
      html = render(image)
      html.should contain("object-fit: contain")
    end

    it "applies object-fit: cover for Fill content mode" do
      image = UI::Image.new("photo.jpg")
      image.content_mode = UI::ContentMode::Fill
      html = render(image)
      html.should contain("object-fit: cover")
    end

    it "applies object-fit: fill for Stretch content mode" do
      image = UI::Image.new("photo.jpg")
      image.content_mode = UI::ContentMode::Stretch
      html = render(image)
      html.should contain("object-fit: fill")
    end

    it "is a self-closing tag (void element)" do
      image = UI::Image.new("test.png")
      html = render(image)
      html.should_not contain("</img>")
    end
  end

  describe "TextField" do
    it "renders to <input> with type=text" do
      field = UI::TextField.new("Enter name")
      html = render(field)
      html.should contain("<input")
      html.should contain("type=\"text\"")
    end

    it "applies placeholder attribute" do
      field = UI::TextField.new("Search...")
      html = render(field)
      html.should contain("placeholder=\"Search...\"")
    end

    it "renders as type=password when secure_entry is true" do
      field = UI::TextField.new("Password")
      field.secure_entry = true
      html = render(field)
      html.should contain("type=\"password\"")
      html.should_not contain("type=\"text\"")
    end

    it "applies value attribute when text is set" do
      field = UI::TextField.new
      field.text = "prefilled"
      html = render(field)
      html.should contain("value=\"prefilled\"")
    end

    it "does not include value attribute when text is empty" do
      field = UI::TextField.new("hint")
      html = render(field)
      html.should_not contain("value=")
    end

    it "applies inputmode for email keyboard type" do
      field = UI::TextField.new("Email")
      field.keyboard_type = UI::KeyboardType::EmailAddress
      html = render(field)
      html.should contain("inputmode=\"email\"")
    end

    it "applies inputmode for numeric keyboard type" do
      field = UI::TextField.new("Number")
      field.keyboard_type = UI::KeyboardType::NumberPad
      html = render(field)
      html.should contain("inputmode=\"numeric\"")
    end

    it "applies font styles" do
      field = UI::TextField.new("Styled")
      field.font = UI::Font.new(size: 14.0)
      html = render(field)
      html.should contain("font-size: 14.0px")
    end

    it "is a self-closing tag (void element)" do
      field = UI::TextField.new
      html = render(field)
      html.should_not contain("</input>")
    end
  end

  describe "ScrollView" do
    it "renders to <div> with overflow" do
      scroll = UI::ScrollView.new
      html = render(scroll)
      html.should contain("<div")
      html.should contain("overflow")
    end

    it "applies overflow-y: auto for vertical-only scrolling" do
      scroll = UI::ScrollView.new
      scroll.scroll_vertical = true
      scroll.scroll_horizontal = false
      html = render(scroll)
      html.should contain("overflow-y: auto")
      html.should contain("overflow-x: hidden")
    end

    it "applies overflow-x: auto for horizontal-only scrolling" do
      scroll = UI::ScrollView.new
      scroll.scroll_horizontal = true
      scroll.scroll_vertical = false
      html = render(scroll)
      html.should contain("overflow-x: auto")
      html.should contain("overflow-y: hidden")
    end

    it "applies overflow: auto for both-axis scrolling" do
      scroll = UI::ScrollView.new
      scroll.scroll_horizontal = true
      scroll.scroll_vertical = true
      html = render(scroll)
      html.should contain("overflow: auto")
    end

    it "renders content child inside the div" do
      content = UI::VStack.new
      content << UI::Label.new("Scrollable Content")
      scroll = UI::ScrollView.new(content)
      html = render(scroll)
      html.should contain("Scrollable Content")
      html.should contain("flex-direction: column")
    end

    it "renders empty div when no content" do
      scroll = UI::ScrollView.new
      html = render(scroll)
      html.should contain("<div")
      html.should contain("</div>")
    end
  end

  describe "Spacer" do
    it "renders to <div> with flex: 1" do
      spacer = UI::Spacer.new
      html = render(spacer)
      html.should contain("<div")
      html.should contain("flex: 1 1 0%")
    end

    it "applies min-height and min-width when min_length > 0" do
      spacer = UI::Spacer.new(min_length: 20.0)
      html = render(spacer)
      html.should contain("min-height: 20.0px")
      html.should contain("min-width: 20.0px")
    end

    it "does not apply min dimensions when min_length is 0" do
      spacer = UI::Spacer.new
      html = render(spacer)
      html.should_not contain("min-height")
      html.should_not contain("min-width")
    end
  end

  describe "common view properties" do
    it "applies padding as CSS padding" do
      label = UI::Label.new("Padded")
      label.padding = UI::EdgeInsets.new(top: 8.0, trailing: 16.0, bottom: 8.0, leading: 16.0)
      html = render(label)
      html.should contain("padding: 8.0px 16.0px 8.0px 16.0px")
    end

    it "does not apply padding when all zeros" do
      label = UI::Label.new("NoPad")
      html = render(label)
      html.should_not contain("padding:")
    end

    it "applies background color as rgba" do
      label = UI::Label.new("BG")
      label.background = UI::Color.new(r: 1.0, g: 0.0, b: 0.0, a: 0.5)
      html = render(label)
      html.should contain("background-color: rgba(255, 0, 0, 0.5)")
    end

    it "does not apply background when nil" do
      label = UI::Label.new("NoBG")
      html = render(label)
      html.should_not contain("background-color")
    end

    it "applies display: none when hidden" do
      label = UI::Label.new("Hidden")
      label.hidden = true
      html = render(label)
      html.should contain("display: none")
    end

    it "does not apply display: none when visible" do
      label = UI::Label.new("Visible")
      html = render(label)
      html.should_not contain("display: none")
    end

    it "applies opacity when less than 1.0" do
      label = UI::Label.new("Faded")
      label.opacity = 0.5
      html = render(label)
      html.should contain("opacity: 0.5")
    end

    it "does not apply opacity when 1.0" do
      label = UI::Label.new("Full")
      html = render(label)
      html.should_not contain("opacity:")
    end

    it "applies view id as HTML id attribute" do
      label = UI::Label.new("IDed")
      label.id = "my-label"
      html = render(label)
      html.should contain("id=\"my-label\"")
    end

    it "applies accessibility_label as aria-label" do
      button = UI::Button.new("X")
      button.accessibility_label = "Close"
      html = render(button)
      html.should contain("aria-label=\"Close\"")
    end
  end

  describe "nested views" do
    it "VStack containing Label and Button produces nested HTML" do
      stack = UI::VStack.new(spacing: 10.0)
      stack << UI::Label.new("Title")
      stack << UI::Button.new("OK")

      html = render(stack)

      # Outer div with flex column
      html.should contain("flex-direction: column")
      html.should contain("gap: 10.0px")

      # Contains both child elements
      html.should contain("<span")
      html.should contain("Title")
      html.should contain("<button")
      html.should contain("OK")
    end

    it "HStack containing Image, Label, and Spacer" do
      row = UI::HStack.new(spacing: 8.0)
      row << UI::Image.new("avatar.png")
      row << UI::Label.new("Username")
      row << UI::Spacer.new

      html = render(row)

      html.should contain("flex-direction: row")
      html.should contain("gap: 8.0px")
      html.should contain("<img")
      html.should contain("avatar.png")
      html.should contain("Username")
      html.should contain("flex: 1 1 0%")
    end

    it "deeply nested tree renders correctly" do
      root = UI::VStack.new(spacing: 16.0)

      header = UI::HStack.new(spacing: 4.0)
      header << UI::Label.new("Title")
      header << UI::Spacer.new

      body = UI::VStack.new(spacing: 8.0)
      body << UI::Label.new("Content")
      body << UI::TextField.new("Search")

      root << header
      root << body

      html = render(root)

      # Root VStack
      html.should contain("flex-direction: column")
      html.should contain("gap: 16.0px")

      # Nested HStack
      html.should contain("flex-direction: row")
      html.should contain("gap: 4.0px")

      # All content present
      html.should contain("Title")
      html.should contain("Content")
      html.should contain("Search")
    end

    it "ScrollView wrapping a VStack with children" do
      content = UI::VStack.new
      content << UI::Label.new("Item 1")
      content << UI::Label.new("Item 2")
      content << UI::Label.new("Item 3")

      scroll = UI::ScrollView.new(content)
      html = render(scroll)

      # Outer ScrollView div
      html.should contain("overflow")

      # Inner VStack
      html.should contain("flex-direction: column")

      # All items
      html.should contain("Item 1")
      html.should contain("Item 2")
      html.should contain("Item 3")
    end

    it "ZStack with background image and overlay label" do
      stack = UI::ZStack.new
      stack << UI::Image.new("bg.jpg")
      stack << UI::Label.new("Overlay Text")

      html = render(stack)

      html.should contain("position: relative")
      html.should contain("bg.jpg")
      html.should contain("Overlay Text")
      html.should contain("position: absolute")
    end

    it "complex layout with properties on nested views" do
      root = UI::VStack.new
      root.padding = UI::EdgeInsets.new(top: 20.0, trailing: 20.0, bottom: 20.0, leading: 20.0)
      root.background = UI::Color.new(r: 0.95, g: 0.95, b: 0.95)

      label = UI::Label.new("Welcome")
      label.font = UI::Font.new(size: 32.0, weight: :bold)

      button = UI::Button.new("Get Started")
      button.opacity = 0.8
      button.background = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)

      root << label
      root << button

      html = render(root)

      # Root properties
      html.should contain("padding: 20.0px 20.0px 20.0px 20.0px")
      html.should contain("background-color: rgba(242, 242, 242, 1.0)")

      # Label font
      html.should contain("font-size: 32.0px")
      html.should contain("font-weight: bold")

      # Button properties
      html.should contain("opacity: 0.8")
      html.should contain("background-color: rgba(0, 122, 255, 1.0)")
    end
  end

  describe "renderer reuse" do
    it "can render multiple views sequentially" do
      renderer = UI::Web::Renderer.new

      label = UI::Label.new("First")
      label.accept(renderer)
      first_html = renderer.output
      first_html.should contain("First")

      button = UI::Button.new("Second")
      button.accept(renderer)
      second_html = renderer.output
      second_html.should contain("Second")
      # After rendering a new view, the output changes to the new view
      second_html.should contain("<button")
    end

    it "render convenience method works" do
      renderer = UI::Web::Renderer.new
      html = renderer.render(UI::Label.new("Convenient"))
      html.should contain("Convenient")
      html.should contain("<span")
    end
  end
end
