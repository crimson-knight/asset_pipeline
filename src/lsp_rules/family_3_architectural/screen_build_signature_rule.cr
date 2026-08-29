# Phase 10A.0c — Family 3 architectural rule: Screen#build must take
# a single `context` argument.
#
# Every `class X < UI::Screen` must declare `def build(ctx)` (or
# `def build(context)`, or any single-arg variant with optional type
# annotation). Zero-arg `def build()` or multi-arg variants are flagged
# because the `UI::ActionDispatcher` and `UI::AmberIntegration` paths
# both call `screen.build(context)` with exactly one argument.
#
# Narrow heuristic (per architecture-decisions.md Decision 3):
#
# - Only inspect classes whose inheritance line matches
#   `class X < (::)?UI::Screen` (no try at deeper subclass chains).
# - Only inspect `def build` declarations textually between that
#   class line and the next top-level `end` at the same indentation.
# - Count parameters via a parens-balanced split. Anything outside
#   parens (method body) is not part of the signature.
# - Allow `def build` with no parens (Crystal lets you omit the
#   `()` for zero-arg defs, but we still flag that). Flag both
#   `def build` (no parens, zero-arg) and `def build()`.
#
# False-positive shape acknowledged in fixtures: nested classes that
# inherit from UI::Screen are flagged only via the immediate
# inheritance line — a class that inherits something else but defines
# `def build` is not touched.

require "../convention_rule"

# Rule: every UI::Screen subclass must declare `def build(ctx)` with
# exactly one argument.
class ScreenBuildSignatureRule < ConventionRule
  CLASS_PATTERN = /^(\s*)class\s+([A-Za-z_][A-Za-z0-9_]*)\s*<\s*(?:::)?UI::Screen\b/

  # `def build` with optional parens. Capture (1) is the entire
  # signature parens (possibly empty), or nil if no parens.
  BUILD_DEF_PATTERN = /^\s*def\s+build\b(\s*\(([^)]*)\))?/

  def rule_name : String
    "family_3/screen_build_signature"
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
        # Find the end of this class's body (line whose `end` has the
        # same indentation as the `class` declaration). Within the
        # body, scan for `def build` declarations.
        body_end = find_class_body_end(lines, i + 1, class_indent)
        scan_class_body(lines, i + 1, body_end, file_path, class_name, diagnostics)
        i = body_end + 1
      else
        i += 1
      end
    end
    diagnostics
  end

  # Returns the line index of the first `end` at exactly the class's
  # opening indentation (or lines.size - 1 if not found — diagnostic
  # is still safe in that pathological case).
  private def find_class_body_end(lines : Array(String), start : Int32, class_indent : String) : Int32
    expected_end = "#{class_indent}end"
    j = start
    while j < lines.size
      line = lines[j].rstrip
      return j if line == expected_end
      j += 1
    end
    lines.size - 1
  end

  private def scan_class_body(lines : Array(String), start : Int32, stop : Int32, file_path : String, class_name : String, diagnostics : Array(Diagnostic)) : Nil
    j = start
    while j <= stop && j < lines.size
      line = lines[j]
      if m = BUILD_DEF_PATTERN.match(line)
        # m[1] is the entire parens group "(args)" or nil.
        # m[2] is the args inside the parens, or nil.
        parens_group = m[1]?
        args_inside = m[2]?
        arity = compute_arity(parens_group, args_inside)
        unless arity == 1
          arity_label = arity == 0 ? "no arguments" : "#{arity} arguments"
          diagnostics << Diagnostic.new(
            file_path: file_path,
            line: j + 1,
            rule_name: rule_name,
            message: "Class '#{class_name}' inherits UI::Screen but its `def build` takes #{arity_label}; expected exactly one (the ScreenContext).",
            suggested_fix: "change to `def build(context : UI::ScreenContext) : UI::View`"
          )
        end
      end
      j += 1
    end
  end

  # Counts arguments. parens_group is the captured "(args)" string or
  # nil if no parens. args_inside is the captured inner-args or nil.
  private def compute_arity(parens_group : String?, args_inside : String?) : Int32
    return 0 if parens_group.nil? # `def build` with no parens.
    inner = args_inside.try(&.strip) || ""
    return 0 if inner.empty? # `def build()`.
    # Split on commas at depth 0. We don't have nested parens in
    # method signatures often, but type annotations like
    # `x : Hash(Symbol, String)` need depth-aware splitting.
    depth = 0
    arg_count = 1
    inner.each_char do |c|
      case c
      when '(', '{', '['
        depth += 1
      when ')', '}', ']'
        depth -= 1
      when ','
        arg_count += 1 if depth == 0
      end
    end
    arg_count
  end
end
