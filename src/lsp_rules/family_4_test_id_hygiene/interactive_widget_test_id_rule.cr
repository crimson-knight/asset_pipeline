# Phase 10A.final — Family 4 test_id hygiene rule:
# every interactive widget instance in samples/specs should set `test_id`.
#
# Interactive widgets (Button, TextField, Toggle, Picker, Slider, etc.)
# instantiated in sample code under `samples/` SHOULD also set `test_id`
# so the AXTest harness and the web `data-testid` selectors can find
# the element without resorting to label text — which is brittle once
# the surface is localized or A/B-tested.
#
# Heuristic (narrow on purpose; we don't parse Crystal):
#
#   1. Scan files under `samples/` only. View-source files under
#      `src/ui/views/` define the widget classes themselves and never
#      instantiate them; spec files under `spec/` are exempt because
#      tests routinely assert on labels directly and do not always need
#      a test_id (the spec_test_id_reference rule below handles the
#      cross-check on the assertion side).
#
#   2. Match assignment-style instantiations only:
#        `<var> = UI::<InteractiveClass>.new(...)`
#      Bare-statement instantiations (`UI::Button.new("Save")` appended
#      directly into a stack without an intermediate variable) are
#      skipped — the rule can't follow the chain through `<<`.
#
#   3. For each captured `<var>`, scan the next `LOOKAHEAD_LINES` lines
#      for `<var>.test_id =` (any leading whitespace tolerated). If not
#      found, emit a diagnostic on the instantiation line.
#
#   4. The set of "interactive" classes is the static
#      `INTERACTIVE_WIDGETS` list below. Layout primitives (VStack /
#      HStack / Card / Spacer / Label / Image / Divider) are excluded —
#      they are decorative or composite containers whose `test_id` is
#      handled at the parent. Adding a new interactive widget to the
#      catalog requires extending this list.
#
# False-positive accommodations:
#
#   - `lint:disable=family_4/interactive_widget_test_id` per-file
#     disable (handled by the runner — no rule-specific code needed).
#   - The `Initial` button inside a `UI::Alert.new([UI::Button.new(...)])`
#     literal array isn't an assignment; it falls through silently.
#   - Test-fixture trees under `*/fixtures/` are already excluded by
#     the runner's `discover_files`.

require "../convention_rule"

# Asserts that interactive widget instances in `samples/` set `test_id`.
class InteractiveWidgetTestIdRule < ConventionRule
  # The catalog of widget classes whose semantics are "user can interact
  # with this." Sourced from the Tier 2 widget list documented in
  # `docs/initiative-cross-platform-ui/tier-matrix.md`. Decorative views
  # (Label, Image, Card, etc.) are intentionally absent.
  INTERACTIVE_WIDGETS = [
    "Button",
    "IconButton",
    "LinkButton",
    "MenuButton",
    "ToggleButton",
    "TextField",
    "SecureField",
    "SearchField",
    "TextArea",
    "TextEditor",
    "Toggle",
    "Checkbox",
    "RadioGroup",
    "Slider",
    "Stepper",
    "SegmentedControl",
    "Picker",
    "DatePicker",
    "TimePicker",
    "ColorPicker",
    "ComboBox",
  ]

  # Number of lines after the instantiation to look ahead for a
  # `<var>.test_id =` assignment. Chosen to cover a typical
  # property-setter block (label, accessibility_label, on_change, etc.)
  # without crossing into the next widget. Spec fixtures exercise the
  # boundary.
  LOOKAHEAD_LINES = 15

  # `<var> = UI::<Class>.new(...)` — captures the variable on the left
  # and the class name on the right. Allows leading whitespace and an
  # optional `::` prefix on the namespace. The class group lists the
  # interactive widget catalog.
  ASSIGNMENT_PATTERN = /^\s*([a-z_][a-zA-Z0-9_]*)\s*=\s*(?:::)?UI::([A-Z][A-Za-z0-9_]*)\.new\b/

  def rule_name : String
    "family_4/interactive_widget_test_id"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless rel.starts_with?("samples/")

    lines = content.lines
    lines.each_with_index do |line, idx|
      if m = ASSIGNMENT_PATTERN.match(line)
        var_name = m[1]
        class_name = m[2]
        next unless INTERACTIVE_WIDGETS.includes?(class_name)
        next if test_id_set_within_window?(lines, idx + 1, var_name)
        diagnostics << Diagnostic.new(
          file_path: file_path,
          line: idx + 1,
          rule_name: rule_name,
          message: "Interactive widget '#{class_name}' assigned to '#{var_name}' " \
                   "is missing a `test_id =` setter within #{LOOKAHEAD_LINES} lines. " \
                   "Set one so AXTest / data-testid selectors can locate it.",
          suggested_fix: "add `#{var_name}.test_id = \"screen-element-name\"` " \
                         "after the instantiation"
        )
      end
    end
    diagnostics
  end

  # Scans `lines[start..start+LOOKAHEAD_LINES]` for a line containing
  # `<var_name>.test_id =`. The receiver match is anchored so a
  # different variable's `.test_id =` doesn't false-positive.
  private def test_id_set_within_window?(lines : Array(String), start : Int32, var_name : String) : Bool
    stop = Math.min(start + LOOKAHEAD_LINES, lines.size - 1)
    pattern = Regex.new("(?:^|\\s|\\(|,)#{Regex.escape(var_name)}\\.test_id\\s*=")
    (start..stop).each do |j|
      return true if pattern.matches?(lines[j])
    end
    false
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
