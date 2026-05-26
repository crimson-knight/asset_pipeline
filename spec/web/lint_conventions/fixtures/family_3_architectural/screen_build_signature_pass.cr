# fixture_for: family_3/screen_build_signature
# expected: pass
# synthetic_path: src/screens/sig_pass_screen.cr
#
# Screen with the canonical `def build(context : UI::ScreenContext)`
# signature. Must pass.

class SigPassScreen < UI::Screen
  def build(context : UI::ScreenContext) : UI::View
    UI::Label.new("ok")
  end
end
