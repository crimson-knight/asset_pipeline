# fixture_for: family_3/screen_build_signature
# expected: fail
# synthetic_path: src/screens/sig_fail_screen.cr
#
# Screen with `def build()` — zero arity. Must be flagged.

class SigFailScreen < UI::Screen
  def build()
    UI::Label.new("oops")
  end
end
