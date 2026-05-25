# Phase 10A.0a — Family 1 naming rule: View subclasses live under views/.
#
# Every concrete subclass of `UI::View` (matched by `< View` inside the
# `UI` module or by `< UI::View` in user code) must live under
# `src/ui/views/` or a configured sample-tree allowlist. The intent is
# to keep the view catalog discoverable and to keep ad-hoc one-off
# views from accreting in random directories.

require "../convention_rule"

# Asserts that concrete `UI::View` subclasses live under an approved
# directory tree.
class ViewSubclassUnderViewsDirRule < ConventionRule
  # `< View` (inside the UI module) OR `< UI::View` (from user code).
  PATTERN = /^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\([^)]*\))?\s*<\s*(?:::)?(?:UI::)?View\b/

  # Approved roots. `src/ui/views/` is the canonical home. Samples may
  # declare one-off views inline; library + production code may not.
  APPROVED_ROOTS = [
    "src/ui/views/",
    "samples/",
  ]

  def rule_name : String
    "family_1/view_subclass_under_views_dir"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = file_path
    rel = rel[Dir.current.size + 1..-1] if rel.starts_with?(Dir.current + "/")
    return diagnostics if APPROVED_ROOTS.any? { |root| rel.starts_with?(root) }
    return diagnostics if rel == "src/ui/view.cr"

    content.each_line.with_index(1) do |line, lineno|
      if m = PATTERN.match(line)
        class_name = m[1]
        next if class_name == "View"
        diagnostics << Diagnostic.new(
          file_path: file_path,
          line: lineno,
          rule_name: rule_name,
          message: "Class '#{class_name}' inherits UI::View but lives outside an approved root (#{APPROVED_ROOTS.join(", ")})",
          suggested_fix: "move file under src/ui/views/ or document a sample allowlist entry"
        )
      end
    end
    diagnostics
  end
end
