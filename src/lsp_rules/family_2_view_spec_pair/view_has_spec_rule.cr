# Phase 10A.0b — Family 2 view-spec pair rule: every UI::View subclass has a
# matching spec file.
#
# For each `class X < UI::View` (or `< View` inside the UI module) declared
# under an approved root (`src/ui/views/`, `samples/`), confirm a spec file
# exists at the expected platform-aware path:
#
#   `spec/web/ui/views/<snake>_spec.cr`            (default)
#   `spec/native_ios/ui/views/<snake>_spec.cr`     (if flag?(:ios) gates the class)
#   `spec/native_macos/ui/views/<snake>_spec.cr`   (if flag?(:macos) gates the class)
#   `spec/native_android/ui/views/<snake>_spec.cr` (if flag?(:android) gates the class)
#
# For a platform-gated class the runner ACCEPTS the spec either at the
# matching native platform path OR at the default `spec/web/` path (because
# the 10C.0 spec-classification rule treats a `{% if flag?(:X) %}`-gated
# spec body as web-resident when it compiles under plain `crystal spec`).
#
# Skipped (false-positive cases):
#   - `src/ui/views/_gate_stubs/*.cr` — Tier-3 compile-time stubs.
#   - The abstract base class file `src/ui/view.cr`.
#   - Any file whose only `class X < View` line is the literal `class View`
#     declaration (the abstract base itself).
#   - Views listed in `view_spec_pair.expected_pending` in
#     `.lint_conventions.yml` (tracked-debt allowlist).
#
# Gate detection: a class declaration is treated as platform-gated when its
# `class` line lies inside an unclosed top-level `{% if flag?(:X) %}` macro
# block. The scanner walks lines, tracks `{% if ... %}` / `{% else %}` /
# `{% end %}` nesting, and records the active platform flag if any.

require "../convention_rule"

# Asserts that every concrete UI::View subclass has a paired spec file at
# the expected platform-aware location.
class ViewHasSpecRule < ConventionRule
  CLASS_PATTERN = /^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)(?:\([^)]*\))?\s*<\s*(?:::)?(?:UI::)?View\b/

  # Macro-guard openers / branches / closers. We track:
  #   - `{% if ... %}` (push a new frame on the stack)
  #   - `{% else %}` and `{% elsif ... %}` (the current frame's flag is
  #     no longer active inside this branch — clear its platform flag
  #     but keep the frame so the matching `{% end %}` pops correctly)
  #   - `{% end %}` (pop the topmost frame)
  FLAG_OPEN_PATTERN   = /\{%\s*if\s+(?:[^%]*?\b)?flag\?\(:([a-z_]+)\)/
  MACRO_OPEN_PATTERN  = /\{%\s*if\b/
  MACRO_END_PATTERN   = /\{%\s*end\s*%\}/
  MACRO_ELSE_PATTERN  = /\{%\s*else\s*%\}/
  MACRO_ELSIF_PATTERN = /\{%\s*elsif\b/

  PLATFORM_SPEC_DIR = {
    "ios"     => "spec/native_ios/ui/views/",
    "macos"   => "spec/native_macos/ui/views/",
    "android" => "spec/native_android/ui/views/",
  }

  DEFAULT_SPEC_DIR = "spec/web/ui/views/"

  @expected_pending : Array(String) = [] of String

  def configure(config : ConventionConfig) : Nil
    @expected_pending = config.view_spec_pair_expected_pending.dup
  end

  def rule_name : String
    "family_2/view_has_spec"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)

    # Skip non-view-source paths.
    return diagnostics unless rel.starts_with?("src/ui/views/") || rel.starts_with?("samples/")
    return diagnostics if rel.starts_with?("src/ui/views/_gate_stubs/")
    return diagnostics if rel == "src/ui/view.cr"
    return diagnostics if @expected_pending.includes?(rel)

    # Track macro-guard nesting. Each frame is the platform flag (or
    # nil) currently active inside the innermost open `{% if %}` block.
    # `{% else %}` / `{% elsif %}` clears the frame's platform flag —
    # code in the else branch is NOT under the original flag. The
    # `active_flag` query takes the DEEPEST non-nil flag so nested
    # `{% if flag?(:ios) %}` inside an outer `{% if flag?(:macos) %}`
    # picks up `:ios`.
    flag_stack = [] of String?
    content.each_line.with_index(1) do |raw, lineno|
      line = raw

      # Process macro openers / branches / closers in order.
      if line.matches?(MACRO_OPEN_PATTERN)
        if m = FLAG_OPEN_PATTERN.match(line)
          flag_stack << m[1]
        else
          flag_stack << nil
        end
      end
      if line.matches?(MACRO_ELSE_PATTERN) || line.matches?(MACRO_ELSIF_PATTERN)
        # In the else / elsif branch, the original `if` flag no longer
        # describes the body. Clear it but keep the frame; the matching
        # `{% end %}` will pop.
        unless flag_stack.empty?
          flag_stack[-1] = nil
        end
      end
      if line.matches?(MACRO_END_PATTERN)
        flag_stack.pop unless flag_stack.empty?
      end

      if m = CLASS_PATTERN.match(line)
        class_name = m[1]
        next if class_name == "View"

        # Deepest platform flag in scope governs the expected spec dir.
        # An outer macos guard wrapping an inner ios guard means the
        # class belongs to the ios platform, not macos.
        active_flag = flag_stack.compact.last?
        # Derive the expected spec basename from the view *file* basename
        # rather than from the class name. This is more honest than
        # snake_case(class_name) because the file basename is canonical
        # (e.g. vstack.cr → vstack_spec.cr, not v_stack_spec.cr).
        view_basename = File.basename(file_path, ".cr")
        expected_path = expected_spec_path(view_basename, active_flag)
        accepts_default = active_flag.nil? || !PLATFORM_SPEC_DIR.has_key?(active_flag)
        candidate_paths = [expected_path]
        # Platform-gated classes also accept the default web spec path
        # because 10C.0 allows `{% if flag?(:X) %}`-gated spec bodies in
        # `spec/web/`.
        candidate_paths << default_spec_path(view_basename) unless accepts_default

        next if candidate_paths.any? { |p| File.exists?(p) }

        diagnostics << Diagnostic.new(
          file_path: file_path,
          line: lineno,
          rule_name: rule_name,
          message: "Class '#{class_name}' inherits UI::View but has no paired spec file at '#{expected_path}'",
          suggested_fix: "create '#{expected_path}' or add '#{rel}' to view_spec_pair.expected_pending in .lint_conventions.yml"
        )
        # Only flag once per file: every view file in the catalog has a
        # single primary view class, and multiple `class X < View`
        # declarations would share the same basename-derived spec.
        break
      end
    end
    diagnostics
  end

  private def expected_spec_path(basename : String, flag : String?) : String
    dir = flag && PLATFORM_SPEC_DIR[flag]? || DEFAULT_SPEC_DIR
    "#{dir}#{basename}_spec.cr"
  end

  private def default_spec_path(basename : String) : String
    "#{DEFAULT_SPEC_DIR}#{basename}_spec.cr"
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
