# Phase 10A.0c — Family 3 architectural rule: no domain-singleton
# mutation inside `UI::Screen#build`.
#
# Architectural rule #1 from the `ui-app` skill: screens are pure
# render functions. App/domain state mutations belong in controllers,
# never in `def build`. Build is called on every render and must be
# idempotent given the same context.
#
# Narrow heuristic (per architecture-decisions.md Decision 3):
#
# - Only inspect classes whose inheritance line matches
#   `class X < (::)?UI::Screen`.
# - Only inspect the `def build(...)` body — find the matching `end`
#   at the same indentation as `def`.
# - Within that body, flag ONLY known domain-singleton mutations:
#   - `<Token>.state.<field> = <expr>` (assignment).
#   - `<Token>.state.<field> << <expr>` (append).
#   - `<Token>.state.<setter_method>(<args>)` for the documented
#     set of mutating setter prefixes: `set_*`, `add_*`, `delete_*`,
#     `remove_*`, `toggle_*`, `update_*`, `clear_*`.
#   - `<Token>` here is the configurable list of known app/domain
#     singletons. Defaults to `Voyager`, `App`. Future user-defined
#     singletons can be added via `.lint_conventions.yml`.
# - Reads (`state = Voyager.state`) and view-local mutation
#   (`view_var << UI::Label.new(...)`) are NOT flagged.
#
# This explicitly does NOT try to flag every possible mutation. The
# narrow rule traps the most common authoring mistake (toggling
# `Voyager.state.hide_completed` in `build`) without false-positiving
# on legitimate view-tree construction.

require "../convention_rule"

# Rule: `def build` on a UI::Screen subclass must not contain a known
# domain-singleton mutation.
class NoAppDomainMutationInScreenBuildRule < ConventionRule
  CLASS_PATTERN = /^(\s*)class\s+([A-Za-z_][A-Za-z0-9_]*)\s*<\s*(?:::)?UI::Screen\b/

  # Matches `def build` or `def build(...)`. The body lives between
  # this line and the next `end` at the same indentation as `def`.
  BUILD_DEF_PATTERN = /^(\s*)def\s+build\b/

  # Mutating setter-method prefixes (for the `<Token>.state.set_foo(x)`
  # heuristic).
  MUTATING_PREFIXES = %w(set_ add_ delete_ remove_ toggle_ update_ clear_)

  def rule_name : String
    "family_3/no_app_domain_mutation_in_screen_build"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    lines = content.lines
    singletons = ["Voyager", "App"]
    singleton_alt = singletons.map { |s| Regex.escape(s) }.join("|")

    # Regex pieces.
    assignment_pattern = /\b(#{singleton_alt})\.state\.([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)/
    append_pattern = /\b(#{singleton_alt})\.state\.([A-Za-z_][A-Za-z0-9_]*)\s*<</
    method_call_pattern = /\b(#{singleton_alt})\.state\.([A-Za-z_][A-Za-z0-9_]*)\s*\(/

    i = 0
    while i < lines.size
      line = lines[i]
      if m = CLASS_PATTERN.match(line)
        class_indent = m[1]
        class_name = m[2]
        class_end = find_block_end(lines, i + 1, class_indent)
        j = i + 1
        while j <= class_end && j < lines.size
          if bm = BUILD_DEF_PATTERN.match(lines[j])
            def_indent = bm[1]
            body_end = find_block_end(lines, j + 1, def_indent)
            scan_build_body(
              lines: lines,
              body_start: j + 1,
              body_end: body_end,
              file_path: file_path,
              class_name: class_name,
              assignment_pattern: assignment_pattern,
              append_pattern: append_pattern,
              method_call_pattern: method_call_pattern,
              diagnostics: diagnostics,
            )
            j = body_end + 1
          else
            j += 1
          end
        end
        i = class_end + 1
      else
        i += 1
      end
    end
    diagnostics
  end

  private def find_block_end(lines : Array(String), start : Int32, indent : String) : Int32
    expected = "#{indent}end"
    j = start
    while j < lines.size
      line = lines[j].rstrip
      return j if line == expected
      j += 1
    end
    lines.size - 1
  end

  private def scan_build_body(
    lines : Array(String),
    body_start : Int32,
    body_end : Int32,
    file_path : String,
    class_name : String,
    assignment_pattern : Regex,
    append_pattern : Regex,
    method_call_pattern : Regex,
    diagnostics : Array(Diagnostic),
  ) : Nil
    j = body_start
    while j <= body_end && j < lines.size
      raw = lines[j]
      stripped_left = raw.lstrip
      # Skip comment-only lines.
      if stripped_left.starts_with?("#")
        j += 1
        next
      end
      # Strip an inline `# ...` comment (top-level only) so we don't
      # match patterns inside trailing comments.
      code_part = strip_inline_comment(raw)

      if m = assignment_pattern.match(code_part)
        singleton = m[1]
        field = m[2]
        diagnostics << Diagnostic.new(
          file_path: file_path,
          line: j + 1,
          rule_name: rule_name,
          message: "Domain mutation `#{singleton}.state.#{field} = ...` inside `#{class_name}#build`. Screen build must be idempotent; move the mutation into the controller layer.",
          suggested_fix: "perform the mutation in the controller action (e.g. `#{class_name.sub("Screen", "Controller")}#...`) and return `render_current_screen`"
        )
      elsif m = append_pattern.match(code_part)
        singleton = m[1]
        field = m[2]
        diagnostics << Diagnostic.new(
          file_path: file_path,
          line: j + 1,
          rule_name: rule_name,
          message: "Domain mutation `#{singleton}.state.#{field} << ...` inside `#{class_name}#build`. Screen build must be idempotent; move the mutation into the controller layer.",
          suggested_fix: "perform the append in the controller action and return `render_current_screen`"
        )
      elsif m = method_call_pattern.match(code_part)
        singleton = m[1]
        method_name = m[2]
        if MUTATING_PREFIXES.any? { |p| method_name.starts_with?(p) }
          diagnostics << Diagnostic.new(
            file_path: file_path,
            line: j + 1,
            rule_name: rule_name,
            message: "Domain mutation `#{singleton}.state.#{method_name}(...)` inside `#{class_name}#build` (method name prefix '#{method_name.split('_').first}_' looks mutating). Move the call into the controller layer.",
            suggested_fix: "perform the mutation in the controller action and return `render_current_screen`"
          )
        end
      end
      j += 1
    end
  end

  # Returns the portion of the line BEFORE any top-level `#` comment
  # (preserves `#` chars inside string literals).
  private def strip_inline_comment(line : String) : String
    in_string = false
    string_char = '\0'
    line.each_char_with_index do |c, idx|
      if in_string
        if c == string_char && (idx == 0 || line[idx - 1] != '\\')
          in_string = false
        end
      else
        case c
        when '"', '\''
          in_string = true
          string_char = c
        when '#'
          return line[0...idx]
        else
          # nothing
        end
      end
    end
    line
  end
end
