# Phase 10A.final — Family 4 test_id hygiene rule:
# unique test_id literals within a single Screen's build method.
#
# A `UI::Screen` subclass's `build` method instantiates the view tree
# for one screen mount. Within that single tree no two views should
# carry the same `test_id` string literal — duplicates make AXTest /
# data-testid lookups non-deterministic ("the first match wins, which
# is whichever the renderer reaches first").
#
# Heuristic (narrow on purpose; we don't parse Crystal):
#
#   1. Find every `class FooScreen < UI::Screen` declaration. (Reuses
#      the Family 1 / Family 3 pattern.)
#
#   2. Within the class body, find every `def build(ctx)` block by
#      scanning forward until the matching `end` at the same
#      indentation as the `def`.
#
#   3. Inside that block, collect every `<receiver>.test_id = "literal"`
#      string. If any string literal appears more than once, emit a
#      diagnostic on the SECOND (and later) occurrence — pointing the
#      author at the duplicate, not the original.
#
#   4. Non-literal test_ids (`<var>.test_id = some_expr`) are skipped.
#      Runtime-computed ids are uncheckable at lint time; if they
#      collide the spec layer catches it.
#
# False-positive accommodation:
#
#   - The rule does NOT cross helper boundaries. If `build` delegates
#     to `private def render_row(idx)` and that helper sets a test_id
#     templated by `idx`, the duplicate-string check sees only the
#     literal form inside `build` itself.

require "../convention_rule"

# Asserts that no two views within a Screen's `build` method declare
# the same string-literal `test_id`.
class UniqueTestIdPerScreenRule < ConventionRule
  CLASS_PATTERN = /^(\s*)class\s+([A-Za-z_][A-Za-z0-9_]*)\s*<\s*(?:::)?UI::Screen\b/
  BUILD_DEF_PATTERN = /^(\s*)def\s+build\b/
  TEST_ID_LITERAL_PATTERN = /\.test_id\s*=\s*"([^"]+)"/

  def rule_name : String
    "family_4/unique_test_id_per_screen"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    lines = content.lines
    i = 0
    while i < lines.size
      line = lines[i]
      if m = CLASS_PATTERN.match(line)
        class_indent = m[1]
        class_name = m[2]
        body_end = find_block_end(lines, i + 1, class_indent)
        scan_class_for_build_blocks(lines, i + 1, body_end, file_path, class_name, diagnostics)
        i = body_end + 1
      else
        i += 1
      end
    end
    diagnostics
  end

  private def find_block_end(lines : Array(String), start : Int32, indent : String) : Int32
    expected_end = "#{indent}end"
    j = start
    while j < lines.size
      return j if lines[j].rstrip == expected_end
      j += 1
    end
    lines.size - 1
  end

  private def scan_class_for_build_blocks(lines : Array(String), start : Int32, stop : Int32, file_path : String, class_name : String, diagnostics : Array(Diagnostic)) : Nil
    j = start
    while j <= stop && j < lines.size
      if m = BUILD_DEF_PATTERN.match(lines[j])
        def_indent = m[1]
        build_end = find_block_end(lines, j + 1, def_indent)
        scan_build_body(lines, j + 1, build_end, file_path, class_name, diagnostics)
        j = build_end + 1
      else
        j += 1
      end
    end
  end

  private def scan_build_body(lines : Array(String), start : Int32, stop : Int32, file_path : String, class_name : String, diagnostics : Array(Diagnostic)) : Nil
    seen_first_lineno = {} of String => Int32
    j = start
    while j <= stop && j < lines.size
      line = lines[j]
      line.scan(TEST_ID_LITERAL_PATTERN) do |m|
        value = m[1]
        if first_lineno = seen_first_lineno[value]?
          diagnostics << Diagnostic.new(
            file_path: file_path,
            line: j + 1,
            rule_name: rule_name,
            message: "Duplicate test_id \"#{value}\" in '#{class_name}#build'; " \
                     "first seen on line #{first_lineno}. AXTest / data-testid " \
                     "lookups become non-deterministic when two views share an id.",
            suggested_fix: "rename one of the duplicates (e.g. append a row " \
                           "index or section qualifier to the second)"
          )
        else
          seen_first_lineno[value] = j + 1
        end
      end
      j += 1
    end
  end
end
