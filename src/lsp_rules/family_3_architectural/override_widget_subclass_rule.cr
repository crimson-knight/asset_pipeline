# Phase 10A.0c — Family 3 architectural rule: `override_widget :foo, Bar`
# must reference a Crystal class constant.
#
# **Scope (honest):** this rule verifies the second argument *looks
# like a Crystal class constant*. It does NOT verify that the class
# actually subclasses `UI::View` — that requires AST + symbol
# resolution outside regex linting and is intentionally out of scope
# (see Phase 10A.0c iter 2 Finding 3 close-handoff entry). The
# Crystal compiler catches unresolved constants at build time, and
# the `UI::App.override_widget` macro validates the class against
# the intent's declared capabilities at registration time — so a
# typo that yields a valid-looking-but-non-View constant is caught
# downstream with a less actionable message; this rule's job is to
# catch the obvious shape violations (symbols, strings, lowercase
# identifiers, hash/array literals) that produce confusing compiler
# errors.
#
# The Phase 10B.0 macros `UI::App.override_widget(:intent_id, WidgetClass)`
# and the `override_widget :intent_id, WidgetClass` class-body form on
# `UI::Screen` subclasses both expect a `UI::View.class` as the second
# argument.
#
# Narrowest honest check: the second argument must look like a
# Crystal class constant — i.e. an identifier or path that starts
# with an uppercase letter (optionally prefixed with `::` and
# possibly module-qualified). Anything that looks like a Symbol
# literal, String literal, Hash/Array literal, Proc, lowercase
# identifier, or method call is flagged.
#
# Narrow heuristic (per architecture-decisions.md Decision 3):
#
# - Only inspect lines whose `lstrip` starts with `override_widget`
#   (the macro call). Tolerate `UI::App.override_widget` and
#   `MyApp.override_widget` forms too.
# - Require exactly two arguments: a Symbol literal first, a class
#   constant token second.
# - The class-constant token regex: optional `::`, then
#   `[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*`. No trailing parens,
#   no string quotes, no Hash/Array literal characters.
# - Skip whole-line comments at entry.
# - For inline-comment + string-literal robustness, scrub each line
#   before regex-matching: replace string-literal interiors with
#   spaces (preserving quotes + line length so column math stays
#   sane) and drop everything after a top-level `#`. This means an
#   inline `# override_widget :foo, BarClass` and a string literal
#   `"override_widget :foo, BarClass"` are both invisible to the
#   entry regex.
#
# False-positive shape acknowledged in fixtures:
#
# - A doc comment containing `override_widget :foo, MyBar` is NOT
#   flagged (comment lines skipped).
# - An inline `# override_widget :foo, BarClass` riding on a
#   non-macro line is NOT flagged (scrubbed before match).
# - A string literal `"override_widget :foo, BarClass"` is NOT
#   flagged (scrubbed before match).
# - A multiline call with the widget class on a continuation line —
#   we concatenate continuation lines until parens balance, so the
#   token is found.

require "../convention_rule"

# Rule: `override_widget :foo, Widget` must reference a class constant.
class OverrideIntentWidgetSubclassRule < ConventionRule
  # Match the `override_widget` macro call. Capture the args after the
  # opening paren OR after the bare-form whitespace.
  #
  # Form A (bare macro inside a class body):
  #   override_widget :foo, BarClass
  # Form B (explicit receiver):
  #   UI::App.override_widget(:foo, BarClass)
  #   MyApp.override_widget(:foo, BarClass)
  ENTRY_PATTERN = /(?:^|\s)((?:[A-Za-z_][A-Za-z0-9_:]*\.)?override_widget)\b/

  CLASS_CONSTANT_PATTERN = /\A(?:::)?[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/

  def rule_name : String
    "family_3/override_widget_subclass"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    raw_lines = content.lines
    # Scrub strings + inline comments once up front so neither the
    # entry match nor the arg-region reader can be fooled by string
    # literals containing `override_widget :foo, Bar` or by inline
    # `# override_widget :foo, Bar` trailing comments. We preserve
    # line count + column positions (string interiors replaced with
    # spaces; comment tail dropped) so diagnostic line numbers are
    # still accurate.
    lines = raw_lines.map { |line| scrub_strings_and_inline_comments(line) }
    i = 0
    while i < lines.size
      raw = lines[i]
      stripped_left = raw.lstrip
      # Skip comment lines.
      if stripped_left.starts_with?("#")
        i += 1
        next
      end
      if (entry = find_entry(raw))
        # Collect args. Two forms:
        #  - parens form: `override_widget(:foo, Bar)` → args between parens.
        #  - bare form:   `override_widget :foo, Bar`  → args after token.
        args_str, end_line = read_args(lines, i, entry[:start_after_token])
        if args_str
          flag_args(args_str, file_path, i + 1, diagnostics)
        end
        i = end_line + 1
      else
        i += 1
      end
    end
    diagnostics
  end

  # Returns nil if no entry. Otherwise a NamedTuple with the index
  # just after the matched token (start of args region).
  private def find_entry(line : String) : NamedTuple(start_after_token: Int32)?
    if m = ENTRY_PATTERN.match(line)
      {start_after_token: m.end}
    else
      nil
    end
  end

  # Reads the argument region starting at line `start_line`, index
  # `start_idx`. Handles both parens and bare forms. Concatenates
  # continuation lines until either a balanced `)` is found (parens
  # form) or the logical line ends (bare form).
  private def read_args(lines : Array(String), start_line : Int32, start_idx : Int32) : Tuple(String?, Int32)
    line = lines[start_line]
    rest = line[start_idx..]
    trimmed = rest.lstrip
    leading_offset = start_idx + (rest.size - trimmed.size)
    if trimmed.starts_with?("(")
      # Parens form.
      open_idx = leading_offset + (rest.size - trimmed.size) + 1
      open_idx = line.index('(', start_idx).not_nil! + 1
      accumulated = line
      end_line = start_line
      depth_state = parens_depth_from(accumulated, open_idx)
      while depth_state > 0 && end_line + 1 < lines.size
        end_line += 1
        accumulated += lines[end_line]
        depth_state = parens_depth_from(accumulated, open_idx)
      end
      if (args = extract_call_args(accumulated, open_idx))
        return {args, end_line}
      end
      return {nil, end_line}
    end
    # Bare form. Args run to end of logical line — Crystal allows
    # newline continuations via trailing commas, but our heuristic
    # only scans the same line. Multi-line bare-form `override_widget`
    # is documented as out of scope (the parens form is the canonical
    # multi-line shape).
    return {trimmed, start_line}
  end

  private def parens_depth_from(text : String, start_idx : Int32) : Int32
    depth = 1
    i = start_idx
    in_string = false
    string_char = '\0'
    while i < text.size
      c = text[i]
      if in_string
        if c == string_char && (i == 0 || text[i - 1] != '\\')
          in_string = false
        end
      else
        case c
        when '"', '\''
          in_string = true
          string_char = c
        when '('
          depth += 1
        when ')'
          depth -= 1
          break if depth == 0
        end
      end
      i += 1
    end
    depth
  end

  private def extract_call_args(text : String, start_idx : Int32) : String?
    depth = 1
    i = start_idx
    in_string = false
    string_char = '\0'
    while i < text.size
      c = text[i]
      if in_string
        if c == string_char && (i == 0 || text[i - 1] != '\\')
          in_string = false
        end
      else
        case c
        when '"', '\''
          in_string = true
          string_char = c
        when '('
          depth += 1
        when ')'
          depth -= 1
          return text[start_idx...i] if depth == 0
        end
      end
      i += 1
    end
    nil
  end

  private def flag_args(args_str : String, file_path : String, line : Int32, diagnostics : Array(Diagnostic)) : Nil
    parts = split_top_level_commas(args_str)
    return if parts.size < 2

    intent_id_part = parts[0].strip
    widget_part = parts[1].strip

    # First arg must look like a Symbol literal. If not, the call shape
    # is not what we expect — bail (don't false-positive on unrelated
    # `*.override_widget` overloads that may exist in user code).
    return unless intent_id_part.starts_with?(':')

    # Strip an optional trailing comment that may have ridden along in
    # the bare form (e.g. `BarClass # widget`).
    if (hash_idx = find_top_level_hash(widget_part))
      widget_part = widget_part[0...hash_idx].strip
    end

    if widget_part.empty? || !CLASS_CONSTANT_PATTERN.matches?(widget_part)
      diagnostics << Diagnostic.new(
        file_path: file_path,
        line: line,
        rule_name: rule_name,
        message: "`override_widget` second argument '#{widget_part}' is not a class constant. Expected a class constant that subclasses `UI::View` (e.g. `UI::InlineActionRow`). Note: this rule only checks the constant shape — actual subclass relationship is validated by the `override_widget` macro at registration time.",
        suggested_fix: "pass the widget class itself (PascalCase identifier or `Module::ClassName`), not a symbol/string/literal"
      )
    end
  end

  # Returns the index of the first `#` character that is not inside a
  # string literal, or nil if none.
  private def find_top_level_hash(text : String) : Int32?
    in_string = false
    string_char = '\0'
    text.each_char_with_index do |c, idx|
      if in_string
        if c == string_char && (idx == 0 || text[idx - 1] != '\\')
          in_string = false
        end
      else
        case c
        when '"', '\''
          in_string = true
          string_char = c
        when '#'
          return idx
        else
          # nothing
        end
      end
    end
    nil
  end

  # Replace string-literal interiors with spaces and drop any
  # top-level inline `# ...` comment. Quotes themselves are kept (so
  # the line still parses as `... "   " ...`); the goal is to make
  # the entry/arg regex blind to any `override_widget` text that
  # lives inside a string or after a `#`. Trailing newline preserved.
  private def scrub_strings_and_inline_comments(line : String) : String
    builder = String::Builder.new
    in_string = false
    string_char = '\0'
    prev_was_backslash = false
    i = 0
    while i < line.size
      c = line[i]
      if in_string
        # Inside string: preserve the quote on close, replace
        # everything else with a space (newline preserved).
        if c == string_char && !prev_was_backslash
          builder << c
          in_string = false
        elsif c == '\n'
          builder << c
        else
          builder << ' '
        end
        prev_was_backslash = (c == '\\' && !prev_was_backslash)
      else
        case c
        when '"', '\''
          builder << c
          in_string = true
          string_char = c
          prev_was_backslash = false
        when '#'
          # Inline comment — drop the rest of the line, but preserve
          # the trailing newline if present.
          if line.ends_with?('\n')
            builder << '\n'
          end
          return builder.to_s
        else
          builder << c
          prev_was_backslash = false
        end
      end
      i += 1
    end
    builder.to_s
  end

  private def split_top_level_commas(args_str : String) : Array(String)
    parts = [] of String
    buf = String::Builder.new
    depth = 0
    in_string = false
    string_char = '\0'
    args_str.each_char_with_index do |c, idx|
      if in_string
        buf << c
        if c == string_char && (idx == 0 || args_str[idx - 1] != '\\')
          in_string = false
        end
      else
        case c
        when '"', '\''
          in_string = true
          string_char = c
          buf << c
        when '(', '{', '['
          depth += 1
          buf << c
        when ')', '}', ']'
          depth -= 1
          buf << c
        when ','
          if depth == 0
            parts << buf.to_s
            buf = String::Builder.new
          else
            buf << c
          end
        else
          buf << c
        end
      end
    end
    last = buf.to_s
    parts << last unless last.strip.empty?
    parts
  end
end
