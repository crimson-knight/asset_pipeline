require "../../spec_helper"
require "../../../../src/ui"

# Phase 10D-refocus — smoke spec for the FullScreenCover + Inspector
# body content rendering. The owner hand-test of the 10D exerciser
# reported "only the title text, not the actual cover / inspector
# content" — verifying here that the body subtree renders inside the
# wrapper chrome on the web renderer (the platform whose output is
# the easiest to assert against). The UIKit + AppKit renderer fixes
# live in the renderer code; this spec exists so a regression of the
# data-path layer (visit method dropping the content reference) is
# caught at unit-test time even though the platform-specific layout
# bugs are not reachable from here.

describe "Phase 10D-refocus body rendering smoke" do
  describe UI::FullScreenCover do
    it "renders multi-child VStack content inside the cover when presented" do
      stack = UI::VStack.new
      stack << UI::Label.new("Cover title").as(UI::View)
      stack << UI::Button.new("Dismiss cover").as(UI::View)
      stack << UI::Label.new("Body explanation").as(UI::View)

      cover = UI::FullScreenCover.new(stack.as(UI::View))
      cover.is_presented = true

      html = UI::Web::Renderer.new.render(cover)
      html.should contain "Cover title"
      html.should contain "Dismiss cover"
      html.should contain "Body explanation"
    end

    it "renders nested content when not presented (hidden, but in DOM)" do
      stack = UI::VStack.new
      stack << UI::Label.new("Hidden title").as(UI::View)
      stack << UI::Button.new("Hidden action").as(UI::View)

      cover = UI::FullScreenCover.new(stack.as(UI::View))
      cover.is_presented = false

      html = UI::Web::Renderer.new.render(cover)
      # Wrapper marked hidden, but children stay in the DOM so a
      # reactive flip of is_presented doesn't have to re-instantiate.
      html.should contain "display: none"
      html.should contain "Hidden title"
      html.should contain "Hidden action"
    end
  end

  describe UI::Inspector do
    it "renders both primary and pane content when presented" do
      primary = UI::VStack.new
      primary << UI::Label.new("Primary heading").as(UI::View)
      primary << UI::Label.new("Primary body").as(UI::View)

      pane = UI::VStack.new
      pane << UI::Label.new("Pane heading").as(UI::View)
      pane << UI::Label.new("Pane body").as(UI::View)

      inspector = UI::Inspector.new(primary.as(UI::View), pane.as(UI::View))
      inspector.is_presented = true
      inspector.preferred_width = 320.0

      html = UI::Web::Renderer.new.render(inspector)
      html.should contain "Primary heading"
      html.should contain "Primary body"
      html.should contain "Pane heading"
      html.should contain "Pane body"
    end

    it "renders the primary content even when the pane is hidden" do
      primary = UI::VStack.new
      primary << UI::Label.new("Only primary").as(UI::View)

      pane = UI::Label.new("Hidden pane")

      inspector = UI::Inspector.new(primary.as(UI::View), pane.as(UI::View))
      inspector.is_presented = false

      html = UI::Web::Renderer.new.render(inspector)
      html.should contain "Only primary"
    end
  end
end
