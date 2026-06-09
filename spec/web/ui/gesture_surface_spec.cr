# Discrete gesture surface — swipe (4 directions) + long-press on UI::View.
#
# Covers the Crystal model layer: enum values, on_swipe registration and
# lookup, on_long_press storage, and that the web renderer compiles without
# any gesture-related output (gestures are silently ignored on web).

require "spec"
require "../../../src/ui"
require "../../../src/ui/renderers/web_renderer"

private def render(view : UI::View) : String
  renderer = UI::Web::Renderer.new
  view.accept(renderer)
  renderer.output
end

describe "UI::SwipeDirection" do
  it "exposes all four cardinal directions" do
    UI::SwipeDirection::Left.should eq(UI::SwipeDirection::Left)
    UI::SwipeDirection::Right.should eq(UI::SwipeDirection::Right)
    UI::SwipeDirection::Up.should eq(UI::SwipeDirection::Up)
    UI::SwipeDirection::Down.should eq(UI::SwipeDirection::Down)
  end

  it "has four distinct members" do
    directions = [
      UI::SwipeDirection::Left,
      UI::SwipeDirection::Right,
      UI::SwipeDirection::Up,
      UI::SwipeDirection::Down,
    ]
    directions.uniq.size.should eq(4)
  end
end

describe "UI::View gesture surface" do
  describe "#swipe_handlers" do
    it "is nil when no swipe handler has been registered" do
      view = UI::Label.new("hello")
      view.swipe_handlers.should be_nil
    end

    it "returns a hash after the first registration" do
      view = UI::Label.new("hello")
      view.on_swipe(UI::SwipeDirection::Down) { }
      view.swipe_handlers.should_not be_nil
    end
  end

  describe "#on_swipe" do
    it "registers a handler for each direction independently" do
      view = UI::Label.new("hello")
      hits = [] of String
      view.on_swipe(UI::SwipeDirection::Left)  { hits << "left"  }
      view.on_swipe(UI::SwipeDirection::Right) { hits << "right" }
      view.on_swipe(UI::SwipeDirection::Up)    { hits << "up"    }
      view.on_swipe(UI::SwipeDirection::Down)  { hits << "down"  }

      handlers = view.swipe_handlers.not_nil!
      handlers.size.should eq(4)
      handlers[UI::SwipeDirection::Left].call
      handlers[UI::SwipeDirection::Right].call
      handlers[UI::SwipeDirection::Up].call
      handlers[UI::SwipeDirection::Down].call
      hits.should eq(["left", "right", "up", "down"])
    end

    it "replaces a previously registered handler for the same direction" do
      view = UI::Label.new("hello")
      hits = [] of Int32
      view.on_swipe(UI::SwipeDirection::Down) { hits << 1 }
      view.on_swipe(UI::SwipeDirection::Down) { hits << 2 }

      view.swipe_handlers.not_nil![UI::SwipeDirection::Down].call
      hits.should eq([2])
    end

    it "handlers are callable procs" do
      view = UI::Label.new("hello")
      called = false
      view.on_swipe(UI::SwipeDirection::Down) { called = true }
      view.swipe_handlers.not_nil![UI::SwipeDirection::Down].call
      called.should be_true
    end

    it "registering one direction does not create entries for others" do
      view = UI::Label.new("hello")
      view.on_swipe(UI::SwipeDirection::Up) { }
      handlers = view.swipe_handlers.not_nil!
      handlers.has_key?(UI::SwipeDirection::Up).should be_true
      handlers.has_key?(UI::SwipeDirection::Down).should be_false
      handlers.has_key?(UI::SwipeDirection::Left).should be_false
      handlers.has_key?(UI::SwipeDirection::Right).should be_false
    end
  end

  describe "#on_long_press" do
    it "defaults to nil" do
      view = UI::Label.new("hello")
      view.on_long_press.should be_nil
    end

    it "stores a proc assigned via property setter" do
      view = UI::Label.new("hello")
      p = -> { nil.as(Nil) }
      view.on_long_press = p
      view.on_long_press.should_not be_nil
    end

    it "stores a block registered via block convenience method" do
      view = UI::Label.new("hello")
      view.on_long_press { }
      view.on_long_press.should_not be_nil
    end

    it "invokes the block when called" do
      view = UI::Label.new("hello")
      fired = false
      view.on_long_press { fired = true }
      view.on_long_press.not_nil!.call
      fired.should be_true
    end

    it "replaces a previously stored long-press handler" do
      view = UI::Label.new("hello")
      hits = [] of Int32
      view.on_long_press { hits << 1 }
      view.on_long_press { hits << 2 }
      view.on_long_press.not_nil!.call
      hits.should eq([2])
    end
  end

  describe "independent per-instance gesture state" do
    it "two views do not share swipe_handlers" do
      a = UI::Label.new("a")
      b = UI::Label.new("b")
      a.on_swipe(UI::SwipeDirection::Left) { }
      b.swipe_handlers.should be_nil
    end

    it "two views do not share on_long_press" do
      a = UI::Label.new("a")
      b = UI::Label.new("b")
      a.on_long_press { }
      b.on_long_press.should be_nil
    end
  end

  describe "web renderer (no-op)" do
    it "renders a Label with swipe handlers without raising" do
      view = UI::Label.new("slide me")
      view.on_swipe(UI::SwipeDirection::Down) { }
      view.on_swipe(UI::SwipeDirection::Left) { }
      view.on_long_press { }
      # Must compile and render without error; gesture attributes NOT emitted on web.
      html = render(view)
      html.should contain("slide me")
      html.should_not contain("swipe")
      html.should_not contain("gesture")
    end

    it "renders a Button with gesture handlers without raising" do
      btn = UI::Button.new("hold me")
      btn.on_long_press { }
      btn.on_swipe(UI::SwipeDirection::Up) { }
      html = render(btn)
      html.should contain("hold me")
    end
  end
end
