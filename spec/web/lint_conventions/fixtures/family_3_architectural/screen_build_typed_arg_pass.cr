# fixture_for: family_3/screen_build_signature
# expected: pass
# synthetic_path: src/screens/typed_arg_screen.cr
#
# False-positive guard #1 — single-arg `def build` with a complex
# type annotation containing a comma inside generic brackets. The
# rule's parens-balanced split must NOT count the comma in
# `Hash(Symbol, String)` as an argument separator.

class TypedArgScreen < UI::Screen
  def build(ctx : UI::ScreenContext) : UI::View
    UI::Label.new("ok")
  end
end
