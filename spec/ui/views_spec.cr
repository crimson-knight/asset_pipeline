require "spec"
require "../../src/ui"

# A test visitor that records which view types were visited, in order.
class TestVisitor < UI::PlatformVisitor
  getter visited : Array(String) = [] of String

  def visit(view : UI::Label)
    @visited << "Label(#{view.text})"
  end

  def visit(view : UI::Button)
    @visited << "Button(#{view.label})"
  end

  def visit(view : UI::VStack)
    @visited << "VStack(#{view.children.size})"
    view.children.each(&.accept(self))
  end

  def visit(view : UI::HStack)
    @visited << "HStack(#{view.children.size})"
    view.children.each(&.accept(self))
  end

  def visit(view : UI::ZStack)
    @visited << "ZStack(#{view.children.size})"
    view.children.each(&.accept(self))
  end

  def visit(view : UI::Image)
    @visited << "Image(#{view.source})"
  end

  def visit(view : UI::TextField)
    @visited << "TextField(#{view.placeholder})"
  end

  def visit(view : UI::ScrollView)
    @visited << "ScrollView"
    view.content.try(&.accept(self))
  end

  def visit(view : UI::Spacer)
    @visited << "Spacer(#{view.min_length})"
  end
end

describe UI do
  describe "value types" do
    it "creates Color with defaults" do
      color = UI::Color.new(r: 1.0, g: 0.5, b: 0.0)
      color.r.should eq(1.0)
      color.g.should eq(0.5)
      color.b.should eq(0.0)
      color.a.should eq(1.0) # default alpha
    end

    it "creates Color with explicit alpha" do
      color = UI::Color.new(r: 0.0, g: 0.0, b: 0.0, a: 0.5)
      color.a.should eq(0.5)
    end

    it "creates Font with defaults" do
      font = UI::Font.new
      font.family.should eq("system")
      font.size.should eq(17.0)
      font.weight.should eq(:regular)
      font.italic.should be_false
    end

    it "creates Font with custom values" do
      font = UI::Font.new(family: "Helvetica", size: 24.0, weight: :bold, italic: true)
      font.family.should eq("Helvetica")
      font.size.should eq(24.0)
      font.weight.should eq(:bold)
      font.italic.should be_true
    end

    it "creates EdgeInsets with defaults" do
      insets = UI::EdgeInsets.new
      insets.top.should eq(0.0)
      insets.trailing.should eq(0.0)
      insets.bottom.should eq(0.0)
      insets.leading.should eq(0.0)
    end

    it "creates EdgeInsets with custom values" do
      insets = UI::EdgeInsets.new(top: 10.0, trailing: 20.0, bottom: 10.0, leading: 20.0)
      insets.top.should eq(10.0)
      insets.trailing.should eq(20.0)
    end
  end

  describe "view instantiation" do
    it "creates a Label" do
      label = UI::Label.new("Hello")
      label.text.should eq("Hello")
      label.font.family.should eq("system")
      label.number_of_lines.should eq(0)
    end

    it "creates a Button" do
      button = UI::Button.new("Tap me")
      button.label.should eq("Tap me")
      button.disabled.should be_false
      button.on_tap.should be_nil
    end

    it "creates a VStack" do
      stack = UI::VStack.new
      stack.spacing.should eq(8.0)
      stack.alignment.should eq(UI::Alignment::Center)
      stack.children.should be_empty
    end

    it "creates an HStack" do
      stack = UI::HStack.new(spacing: 12.0, alignment: UI::Alignment::Top)
      stack.spacing.should eq(12.0)
      stack.alignment.should eq(UI::Alignment::Top)
      stack.children.should be_empty
    end

    it "creates a ZStack" do
      stack = UI::ZStack.new(alignment: UI::Alignment::Leading)
      stack.alignment.should eq(UI::Alignment::Leading)
      stack.children.should be_empty
    end

    it "creates an Image" do
      image = UI::Image.new("icon_star")
      image.source.should eq("icon_star")
      image.content_mode.should eq(UI::ContentMode::Fit)
      image.tint_color.should be_nil
    end

    it "creates a TextField" do
      field = UI::TextField.new("Enter name")
      field.placeholder.should eq("Enter name")
      field.text.should eq("")
      field.secure_entry.should be_false
      field.keyboard_type.should eq(UI::KeyboardType::Default)
    end

    it "creates a ScrollView" do
      scroll = UI::ScrollView.new
      scroll.content.should be_nil
      scroll.scroll_horizontal.should be_false
      scroll.scroll_vertical.should be_true
      scroll.shows_indicators.should be_true
    end

    it "creates a Spacer" do
      spacer = UI::Spacer.new
      spacer.min_length.should eq(0.0)
    end

    it "creates a Spacer with min length" do
      spacer = UI::Spacer.new(min_length: 16.0)
      spacer.min_length.should eq(16.0)
    end
  end

  describe "view base properties" do
    it "sets and gets id" do
      label = UI::Label.new("Test")
      label.id.should be_nil
      label.id = "my-label"
      label.id.should eq("my-label")
    end

    it "sets and gets accessibility_label" do
      button = UI::Button.new("X")
      button.accessibility_label = "Close button"
      button.accessibility_label.should eq("Close button")
    end

    it "sets padding" do
      label = UI::Label.new("Padded")
      label.padding = UI::EdgeInsets.new(top: 8.0, trailing: 16.0, bottom: 8.0, leading: 16.0)
      label.padding.top.should eq(8.0)
      label.padding.leading.should eq(16.0)
    end

    it "sets background color" do
      label = UI::Label.new("Colored")
      label.background.should be_nil
      label.background = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
      label.background.not_nil!.r.should eq(1.0)
    end

    it "sets hidden" do
      label = UI::Label.new("Secret")
      label.hidden.should be_false
      label.hidden = true
      label.hidden.should be_true
    end

    it "sets opacity" do
      label = UI::Label.new("Faded")
      label.opacity.should eq(1.0)
      label.opacity = 0.5
      label.opacity.should eq(0.5)
    end
  end

  describe "visitor pattern" do
    it "Label accepts visitor" do
      visitor = TestVisitor.new
      label = UI::Label.new("Hello")
      label.accept(visitor)
      visitor.visited.should eq(["Label(Hello)"])
    end

    it "Button accepts visitor" do
      visitor = TestVisitor.new
      button = UI::Button.new("OK")
      button.accept(visitor)
      visitor.visited.should eq(["Button(OK)"])
    end

    it "VStack accepts visitor and visits children" do
      visitor = TestVisitor.new
      stack = UI::VStack.new
      stack << UI::Label.new("First")
      stack << UI::Label.new("Second")
      stack.accept(visitor)
      visitor.visited.should eq(["VStack(2)", "Label(First)", "Label(Second)"])
    end

    it "HStack accepts visitor and visits children" do
      visitor = TestVisitor.new
      stack = UI::HStack.new
      stack << UI::Button.new("A")
      stack << UI::Spacer.new
      stack << UI::Button.new("B")
      stack.accept(visitor)
      visitor.visited.should eq(["HStack(3)", "Button(A)", "Spacer(0.0)", "Button(B)"])
    end

    it "ZStack accepts visitor and visits children" do
      visitor = TestVisitor.new
      stack = UI::ZStack.new
      stack << UI::Image.new("bg")
      stack << UI::Label.new("Overlay")
      stack.accept(visitor)
      visitor.visited.should eq(["ZStack(2)", "Image(bg)", "Label(Overlay)"])
    end

    it "Image accepts visitor" do
      visitor = TestVisitor.new
      image = UI::Image.new("photo")
      image.accept(visitor)
      visitor.visited.should eq(["Image(photo)"])
    end

    it "TextField accepts visitor" do
      visitor = TestVisitor.new
      field = UI::TextField.new("Search...")
      field.accept(visitor)
      visitor.visited.should eq(["TextField(Search...)"])
    end

    it "ScrollView accepts visitor and visits content" do
      visitor = TestVisitor.new
      content = UI::VStack.new
      content << UI::Label.new("Scrollable")
      scroll = UI::ScrollView.new(content)
      scroll.accept(visitor)
      visitor.visited.should eq(["ScrollView", "VStack(1)", "Label(Scrollable)"])
    end

    it "Spacer accepts visitor" do
      visitor = TestVisitor.new
      spacer = UI::Spacer.new(min_length: 20.0)
      spacer.accept(visitor)
      visitor.visited.should eq(["Spacer(20.0)"])
    end
  end

  describe "children arrays" do
    it "VStack children accepts mixed view types" do
      stack = UI::VStack.new
      stack << UI::Label.new("Title")
      stack << UI::Button.new("Action")
      stack << UI::Image.new("icon")
      stack << UI::Spacer.new

      stack.children.size.should eq(4)
      stack.children[0].should be_a(UI::Label)
      stack.children[1].should be_a(UI::Button)
      stack.children[2].should be_a(UI::Image)
      stack.children[3].should be_a(UI::Spacer)
    end

    it "HStack children accepts mixed view types" do
      stack = UI::HStack.new
      stack << UI::Label.new("Name:")
      stack << UI::TextField.new("Enter name")
      stack.children.size.should eq(2)
    end

    it "ZStack children accepts mixed view types" do
      stack = UI::ZStack.new
      stack << UI::Image.new("background")
      stack << UI::VStack.new
      stack.children.size.should eq(2)
    end

    it "<< returns self for chaining" do
      stack = UI::VStack.new
      result = stack << UI::Label.new("A")
      result.should be(stack)

      # Chaining
      stack << UI::Label.new("B") << UI::Label.new("C")
      # Note: the second << is on VStack (returned by first <<), not on Label
      stack.children.size.should eq(3)
    end
  end

  describe "Button on_tap callback" do
    it "stores and calls on_tap proc" do
      called = false
      button = UI::Button.new("Tap") { called = true; nil }
      button.on_tap.should_not be_nil
      button.on_tap.try(&.call)
      called.should be_true
    end

    it "allows setting on_tap after construction" do
      button = UI::Button.new("Later")
      button.on_tap.should be_nil

      counter = 0
      button.on_tap = ->{ counter += 1; nil }
      button.on_tap.try(&.call)
      button.on_tap.try(&.call)
      counter.should eq(2)
    end
  end

  describe "TextField on_change callback" do
    it "stores and calls on_change proc" do
      received = ""
      field = UI::TextField.new("Type here") { |text| received = text; nil }
      field.on_change.should_not be_nil
      field.on_change.try(&.call("hello"))
      received.should eq("hello")
    end

    it "allows setting on_change after construction" do
      field = UI::TextField.new
      values = [] of String
      field.on_change = ->(text : String) { values << text; nil }
      field.on_change.try(&.call("a"))
      field.on_change.try(&.call("ab"))
      values.should eq(["a", "ab"])
    end
  end

  describe "recursive view tree" do
    it "VStack containing HStack containing Labels" do
      root = UI::VStack.new(spacing: 16.0)

      header = UI::HStack.new(spacing: 4.0)
      header << UI::Image.new("avatar")
      header << UI::Label.new("Username")
      header << UI::Spacer.new

      body = UI::VStack.new(spacing: 4.0)
      body << UI::Label.new("Post content here")

      footer = UI::HStack.new(spacing: 12.0)
      footer << UI::Button.new("Like")
      footer << UI::Button.new("Reply")
      footer << UI::Spacer.new

      root << header
      root << body
      root << footer

      root.children.size.should eq(3)
      root.children[0].should be_a(UI::HStack)
      root.children[1].should be_a(UI::VStack)
      root.children[2].should be_a(UI::HStack)

      # Verify nested structure
      header_view = root.children[0].as(UI::HStack)
      header_view.children.size.should eq(3)
      header_view.children[0].should be_a(UI::Image)
      header_view.children[1].should be_a(UI::Label)
      header_view.children[2].should be_a(UI::Spacer)
    end

    it "traverses deep tree with visitor" do
      visitor = TestVisitor.new

      root = UI::VStack.new
      row = UI::HStack.new
      row << UI::Label.new("A")
      row << UI::Label.new("B")
      root << row
      root << UI::Label.new("C")

      root.accept(visitor)

      visitor.visited.should eq([
        "VStack(2)",
        "HStack(2)",
        "Label(A)",
        "Label(B)",
        "Label(C)",
      ])
    end

    it "ScrollView wrapping a complex tree" do
      visitor = TestVisitor.new

      content = UI::VStack.new
      content << UI::Label.new("Header")
      inner = UI::HStack.new
      inner << UI::Button.new("Go")
      content << inner
      content << UI::TextField.new("Search")

      scroll = UI::ScrollView.new(content)
      scroll.accept(visitor)

      visitor.visited.should eq([
        "ScrollView",
        "VStack(3)",
        "Label(Header)",
        "HStack(1)",
        "Button(Go)",
        "TextField(Search)",
      ])
    end
  end
end
