# Phase 10A.0c — Family 3 architectural rule: `UI::Intent.resolve(...)`
# callers must use the iter-9 signature.
#
# The Phase 10B.0 resolver signature is:
#
#     UI::Intent.resolve(intent_id, context, capabilities_required: ...)
#
# - Positional args: exactly two (`intent_id`, `context`).
# - Optional kwarg: `capabilities_required:`.
# - The earlier implementer drift toward a `screen_class:` kwarg was
#   retired in iter-9; the active screen class travels on
#   `context.active_screen_class` instead. Callers passing
#   `screen_class:` are stale.
#
# This rule flags:
# 1. `UI::Intent.resolve` calls that pass a `screen_class:` kwarg.
# 2. `UI::Intent.resolve` calls with three or more positional args
#    (no kwarg). Callers must use `capabilities_required: ...` for
#    the third value.
#
# Narrow heuristic (per architecture-decisions.md Decision 3):
#
# - Only inspect lines containing the literal text
#   `UI::Intent.resolve(`. Tolerate optional leading `::`.
# - Concatenate continuation lines until parens balance to handle
#   multi-line calls.
# - Don't parse Crystal. Treat each top-level (depth-0) comma as an
#   argument separator. Recognize kwargs by the `name:` prefix
#   (where `name` is `[A-Za-z_][A-Za-z0-9_]*`).
# - False-positive shape acknowledged: a doc comment string
#   containing `UI::Intent.resolve(:foo, ctx, X)` could trip the
#   rule. Mitigation: lines whose `lstrip` starts with `#` (a
#   comment) are skipped at the entry point.

require "../convention_rule"

# Rule: `UI::Intent.resolve(...)` callers must use the
# `capabilities_required:` kwarg for the third argument (not
# positional, not the retired `screen_class:` kwarg).
class IntentResolveCapabilityArgRule < ConventionRule
  ENTRY_PATTERN = /(?:::)?UI::Intent\.resolve\s*\(/

  KWARG_PATTERN = /^([A-Za-z_][A-Za-z0-9_]*)\s*:/

  def rule_name : String
    "family_3/intent_resolve_capability_arg"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    lines = content.lines
    i = 0
    while i < lines.size
      raw = lines[i]
      stripped = raw.lstrip
      if stripped.starts_with?("#")
        i += 1
        next
      end
      if (entry_idx = scan_entry(raw))
        # Concatenate continuation lines until parens balance.
        accumulated = raw
        depth = parens_depth_from(raw, entry_idx)
        end_line = i
        while depth > 0 && end_line + 1 < lines.size
          end_line += 1
          accumulated += lines[end_line]
          depth = parens_depth_from(accumulated, entry_idx)
        end
        if (args_str = extract_call_args(accumulated, entry_idx))
          flag_call(args_str, file_path, i + 1, diagnostics)
        end
        i = end_line + 1
      else
        i += 1
      end
    end
    diagnostics
  end

  # Returns the index inside `line` where the opening `(` after
  # `UI::Intent.resolve` lives, or `nil` if no entry on this line.
  private def scan_entry(line : String) : Int32?
    if m = ENTRY_PATTERN.match(line)
      m.end
    else
      nil
    end
  end

  # Computes parenthesis depth from `start_idx` (which is immediately
  # AFTER the opening `(` of the resolve call). Returns the net depth
  # at end of string, where `> 0` means the call is still open.
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

  # Extracts the argument list text (between the `(` at `start_idx`
  # and the matching `)`). Returns nil if no matching `)` is found.
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

  # Inspects the argument string and emits diagnostics for stale
  # signatures.
  private def flag_call(args_str : String, file_path : String, line : Int32, diagnostics : Array(Diagnostic)) : Nil
    parts = split_top_level_commas(args_str)
    positional_count = 0
    parts.each do |part|
      stripped = part.strip
      next if stripped.empty?
      if m = KWARG_PATTERN.match(stripped)
        kwarg_name = m[1]
        if kwarg_name == "screen_class"
          diagnostics << Diagnostic.new(
            file_path: file_path,
            line: line,
            rule_name: rule_name,
            message: "`UI::Intent.resolve` no longer accepts the `screen_class:` kwarg (retired in 10B.0 iter-9).",
            suggested_fix: "remove `screen_class:` — the active screen class travels on `ctx.active_screen_class`"
          )
        end
      else
        positional_count += 1
      end
    end
    if positional_count >= 3
      diagnostics << Diagnostic.new(
        file_path: file_path,
        line: line,
        rule_name: rule_name,
        message: "`UI::Intent.resolve` accepts only two positional args (`intent_id`, `context`); the third value must be the `capabilities_required:` kwarg.",
        suggested_fix: "convert the third argument to `capabilities_required: {...}`"
      )
    end
  end

  # Splits `args_str` on commas that are at depth 0 (outside parens,
  # braces, brackets, and string literals).
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
