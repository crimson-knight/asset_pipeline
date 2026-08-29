# fixture_for: family_3/screen_build_signature
# expected: pass
# synthetic_path: src/screens/helper_method_screen.cr
#
# False-positive guard #2 — Screen with `def build(ctx)` PLUS a
# private helper method `def build_header()`. Only `def build` itself
# (whole-word match) should be inspected; `build_header` must NOT
# trip the rule.

class HelperMethodScreen < UI::Screen
  def build(ctx : UI::ScreenContext) : UI::View
    root = UI::VStack.new(spacing: 8.0)
    root << build_header()
    root.as(UI::View)
  end

  private def build_header() : UI::View
    UI::Label.new("Header")
  end
end
