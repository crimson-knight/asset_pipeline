# Phase 10A.final — Family 4 test_id hygiene rule:
# spec test_id references must match a setter in the same file.
#
# Spec files frequently locate a widget by `test_id` via the AXTest or
# data-testid drivers. Example:
#
#     btn = root.find_by_test_id("demo-sign-in-submit")
#
# That string MUST appear somewhere in the same spec file as
# `<var>.test_id = "demo-sign-in-submit"` — otherwise the locator
# refers to a value nothing sets, and the assertion will silently fail
# (or succeed against a stale value). Catching that mismatch is the
# rule's purpose.
#
# Heuristic (narrow on purpose; we don't run the spec):
#
#   1. Scan only `_spec.cr` files.
#
#   2. Collect the set of test_id values DECLARED in the file. A
#      declaration is a line matching:
#        `<receiver>.test_id = "literal"`
#      Receiver may be any expression (we don't try to parse it).
#
#   3. Collect the set of test_id values REFERENCED in the file. A
#      reference is a string literal that appears as the only argument
#      to one of the known AXTest / web locator methods:
#        `find_by_test_id("literal")`
#        `find_test_id("literal")`
#        `with_test_id("literal")`
#        `test_id_eq("literal")`
#        `test_id: "literal"`              (named-arg form)
#        `data-testid="literal"`           (raw HTML attribute string)
#
#   4. For every reference not present in the declaration set, emit a
#      diagnostic.
#
#   5. The cross-file case (helper module declares the test_id and the
#      spec references it) is OUT OF SCOPE — we don't follow requires.
#      A spec that relies on a cross-file declaration can suppress the
#      rule per-file with `# lint:disable=family_4/spec_test_id_reference`.

require "../convention_rule"

# Asserts that every test_id value REFERENCED in a spec file is also
# DECLARED via `<var>.test_id = "..."` somewhere in the same file.
class SpecTestIdReferenceRule < ConventionRule
  DECLARATION_PATTERN = /\.test_id\s*=\s*"([^"]+)"/

  # Recognized referrer call shapes. Each pattern captures the string
  # literal that constitutes the test_id being looked up.
  REFERENCE_PATTERNS = [
    /\bfind_by_test_id\(\s*"([^"]+)"\s*\)/,
    /\bfind_test_id\(\s*"([^"]+)"\s*\)/,
    /\bwith_test_id\(\s*"([^"]+)"\s*\)/,
    /\btest_id_eq\(\s*"([^"]+)"\s*\)/,
    /\btest_id:\s*"([^"]+)"/,
    /data-testid="([^"]+)"/,
  ]

  def rule_name : String
    "family_4/spec_test_id_reference"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless rel.ends_with?("_spec.cr")

    declared = collect_declarations(content)
    references = collect_references(content)
    references.each do |(value, lineno)|
      next if declared.includes?(value)
      diagnostics << Diagnostic.new(
        file_path: file_path,
        line: lineno,
        rule_name: rule_name,
        message: "Spec references test_id \"#{value}\" but no " \
                 "`<receiver>.test_id = \"#{value}\"` declaration is " \
                 "visible in this file. The locator will resolve to " \
                 "no element (or a stale one). Either set the test_id " \
                 "in the same file's test setup or suppress this rule " \
                 "if the declaration lives in a shared helper.",
        suggested_fix: "add `<view>.test_id = \"#{value}\"` to the " \
                       "test setup, or `# lint:disable=family_4/" \
                       "spec_test_id_reference` if cross-file declared"
      )
    end
    diagnostics
  end

  private def collect_declarations(content : String) : Set(String)
    declared = Set(String).new
    content.scan(DECLARATION_PATTERN) do |m|
      declared << m[1]
    end
    declared
  end

  # Returns `[{test_id_value, lineno}, ...]`. The line is the 1-based
  # source line where the reference appears, used as the diagnostic
  # location.
  private def collect_references(content : String) : Array(Tuple(String, Int32))
    out = [] of Tuple(String, Int32)
    content.each_line.with_index(1) do |line, lineno|
      REFERENCE_PATTERNS.each do |pat|
        line.scan(pat) do |m|
          out << {m[1], lineno}
        end
      end
    end
    out
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
