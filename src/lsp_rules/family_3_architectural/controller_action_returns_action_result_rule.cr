# Phase 10A.0c — Family 3 architectural rule: controller action
# methods must return a `UI::ActionResult`.
#
# `UI::Controller` action methods (those whose declared return type is
# `UI::ActionResult`) must terminate with an expression that yields an
# `ActionResult` value. The dispatcher applies the returned result to
# the navigation coordinator + host; a method that accidentally returns
# `Nil` (because the last expression is a setter or a `puts`) silently
# becomes a no-op at runtime.
#
# Narrow heuristic (per architecture-decisions.md Decision 3):
#
# - Only inspect classes whose inheritance line matches
#   `class X < (::)?UI::Controller`.
# - Two narrow gates surface a method as an "action handler":
#   (a) `def name(...) : UI::ActionResult` — the explicit
#       return-type annotation (optional `::` prefix accepted), OR
#   (b) the method is preceded by an `action_handler :name` macro
#       call (the next `def name(...)` after that line is treated
#       as the handler, even without the explicit annotation).
#   Methods that match neither gate are NOT checked.
# - Find the final non-blank, non-comment line of the method body
#   (the line immediately before the matching `end`).
# - Allow that line to:
#   * Be an `ActionResult` constructor: `UI::ActionResult::X.new(...)`.
#   * Be one of the documented controller helper methods:
#     `navigate_to`, `pop_navigation`, `render_current_screen`,
#     `replace_root`, `respond_with`.
#   * Be an explicit `return <expr>` of the above forms.
#   * Be a `case ... end` block whose every branch ends in one of
#     the above (heuristic accept — we don't verify each branch,
#     we accept `end` lines).
#   * Be a call to another method whose return type the caller
#     trusts (best-effort: any identifier call returning is NOT
#     flagged — see false-positive notes below).
# - Flag the method ONLY when the final line is plainly a
#   non-return expression like an assignment (`x = y`), a setter
#   (`foo.bar = baz`), a `puts/print/p`, or an empty body.
#
# False-positive shape acknowledged: a controller method that ends
# with a call to a private helper returning `UI::ActionResult` would
# pass this check (the helper's return type is invisible to regex).
# A method ending with an `if/else` branch where one branch returns
# Nil — we treat the trailing `end` as acceptable. The rule's job is
# to catch the most common authoring mistake (forgetting to return at
# all), not to prove total correctness.

require "../convention_rule"

# Rule: controller action methods declared `: UI::ActionResult` must
# end with an expression that plausibly returns an ActionResult.
class ControllerActionReturnsActionResultRule < ConventionRule
  CLASS_PATTERN = /^(\s*)class\s+([A-Za-z_][A-Za-z0-9_]*)\s*<\s*(?:::)?UI::Controller\b/

  # Matches `def [protected|private|public] name(args) : UI::ActionResult`.
  # The visibility modifier is on a previous line in idiomatic Crystal,
  # so we don't try to match it here.
  ACTION_DEF_PATTERN = /^(\s*)def\s+([A-Za-z_][A-Za-z0-9_]*[?!=]?)\s*(?:\([^)]*\))?\s*:\s*(?:::)?UI::ActionResult\b/

  # Matches any `def name(args)` (with or without return-type
  # annotation). Used in conjunction with `action_handler :name` to
  # find decorated handlers.
  ANY_DEF_PATTERN = /^(\s*)def\s+([A-Za-z_][A-Za-z0-9_]*[?!=]?)\b/

  # Matches `action_handler :name` (optionally `action_handler(:name)`).
  ACTION_HANDLER_DECL_PATTERN = /^\s*action_handler[\s(]+:([A-Za-z_][A-Za-z0-9_]*[?!=]?)\b/

  ALLOWED_HELPER_NAMES = %w(
    navigate_to
    pop_navigation
    render_current_screen
    replace_root
    respond_with
  )

  ACTION_RESULT_CONSTRUCTOR = /(?:::)?UI::ActionResult::[A-Za-z_][A-Za-z0-9_]*\.new\b/

  ASSIGNMENT_PATTERN = /^[^=<>!]*[A-Za-z0-9_\)\]]\s*=(?!=)/

  PUTS_PATTERN = /^\s*(puts|print|p|STDERR|STDOUT)\b/

  def rule_name : String
    "family_3/controller_action_returns_action_result"
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
        class_end = find_block_end(lines, i + 1, class_indent)
        scan_controller_body(
          lines: lines,
          start: i + 1,
          stop: class_end,
          file_path: file_path,
          class_name: class_name,
          diagnostics: diagnostics,
        )
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

  private def scan_controller_body(
    lines : Array(String),
    start : Int32,
    stop : Int32,
    file_path : String,
    class_name : String,
    diagnostics : Array(Diagnostic),
  ) : Nil
    # First pass: collect the set of names declared as
    # `action_handler :name`. These methods are also action handlers
    # for our purposes even if they lack the `: UI::ActionResult`
    # return-type annotation.
    decorated_names = Set(String).new
    k = start
    while k <= stop && k < lines.size
      if dm = ACTION_HANDLER_DECL_PATTERN.match(lines[k])
        decorated_names << dm[1]
      end
      k += 1
    end

    j = start
    while j <= stop && j < lines.size
      raw = lines[j]
      typed_match = ACTION_DEF_PATTERN.match(raw)
      any_def_match = ANY_DEF_PATTERN.match(raw)

      handler_match = nil
      origin = ""
      if typed_match
        handler_match = typed_match
        origin = "typed"
      elsif any_def_match && decorated_names.includes?(any_def_match[2])
        handler_match = any_def_match
        origin = "decorated"
      end

      if handler_match
        def_indent = handler_match[1]
        method_name = handler_match[2]
        body_end = find_block_end(lines, j + 1, def_indent)
        if body_end > j
          terminal_line_idx = find_terminal_line(lines, j + 1, body_end - 1)
          if terminal_line_idx
            terminal_line = lines[terminal_line_idx]
            unless line_returns_action_result?(terminal_line)
              diagnostics << Diagnostic.new(
                file_path: file_path,
                line: terminal_line_idx + 1,
                rule_name: rule_name,
                message: handler_message(class_name, method_name, origin, kind: :terminal),
                suggested_fix: "end with `navigate_to(...)`, `pop_navigation`, `render_current_screen`, `replace_root(...)`, `respond_with(view)`, or an explicit `UI::ActionResult::*` constructor"
              )
            end
          else
            diagnostics << Diagnostic.new(
              file_path: file_path,
              line: j + 1,
              rule_name: rule_name,
              message: handler_message(class_name, method_name, origin, kind: :empty),
              suggested_fix: "return one of the controller helpers (e.g. `render_current_screen`)"
            )
          end
        end
        j = body_end + 1
      else
        j += 1
      end
    end
  end

  private def handler_message(class_name : String, method_name : String, origin : String, kind : Symbol) : String
    surface = origin == "typed" ? "declares `: UI::ActionResult`" : "is decorated with `action_handler :#{method_name}`"
    case kind
    when :terminal
      "Controller action `#{class_name}##{method_name}` #{surface} but its terminal expression does not appear to return one. The dispatcher silently no-ops on Nil returns."
    when :empty
      "Controller action `#{class_name}##{method_name}` #{surface} but has an empty body."
    else
      "Controller action `#{class_name}##{method_name}` #{surface}."
    end
  end

  # Returns the line index of the last non-blank, non-comment line in
  # the inclusive range [start..stop], or nil if none exist.
  private def find_terminal_line(lines : Array(String), start : Int32, stop : Int32) : Int32?
    k = stop
    while k >= start
      raw = lines[k]
      stripped = raw.strip
      if stripped.empty? || stripped.starts_with?("#")
        k -= 1
        next
      end
      return k
    end
    nil
  end

  private def line_returns_action_result?(raw : String) : Bool
    # Trim leading whitespace and (if present) an explicit `return `.
    line = raw.strip
    line = line.sub(/^return\s+/, "")
    # Strip an inline `# ...` comment.
    line = strip_inline_comment(line)
    return false if line.empty?

    # Helper-method call (e.g. `navigate_to(:foo)` or `pop_navigation`).
    ALLOWED_HELPER_NAMES.each do |helper|
      if line.starts_with?(helper)
        rest = line[helper.size..]?
        if rest.nil? || rest.empty? || !rest[0].ascii_alphanumeric? && rest[0] != '_'
          return true
        end
      end
    end

    # `UI::ActionResult::X.new(...)` constructor.
    return true if line.matches?(ACTION_RESULT_CONSTRUCTOR)

    # Trailing `end` from a control-flow block (case/if/unless/begin).
    # Heuristic accept: we trust the branches.
    return true if line == "end"

    # Closing bracket / paren of a multi-line expression — accept as
    # plausible return (the actual ActionResult constructor likely
    # opened on an earlier line).
    return true if line.starts_with?(")") || line.starts_with?("]")

    # Plain `raise ...` is an early exit — Crystal infers `NoReturn`
    # for the method's tail, which is compatible with any return type.
    return true if line.starts_with?("raise ") || line == "raise"

    # An `if cond then expr` or guard-like one-liner that contains an
    # allowed helper is also accepted.
    ALLOWED_HELPER_NAMES.each do |helper|
      return true if line.includes?(helper)
    end
    return true if line.matches?(ACTION_RESULT_CONSTRUCTOR)

    # A bare identifier (e.g. `result`) — could be a local variable
    # returning an `ActionResult`. Accept (avoid false positive).
    return true if line.matches?(/^[a-z_][A-Za-z0-9_]*\??\s*$/)

    # An assignment expression returns the assigned value (Crystal),
    # which is almost certainly NOT an `ActionResult` for our use
    # case. Flag.
    return false if line.matches?(ASSIGNMENT_PATTERN)

    # A `puts/print` is plainly returning Nil.
    return false if line.matches?(PUTS_PATTERN)

    # Default: accept (be conservative — only flag clear violations).
    true
  end

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
          return line[0...idx].rstrip
        else
          # nothing
        end
      end
    end
    line
  end
end
