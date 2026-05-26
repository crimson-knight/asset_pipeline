# Phase 10A.0b — Family 2 view-spec pair rule: spec `describe Foo` references
# a real source-tree class.
#
# Every spec file's top-level `describe <Identifier> do` block must
# reference a class/module/struct that exists somewhere in `src/`.
# Catches drift between renamed classes and stale spec headers.
#
# Acceptable forms (NOT flagged):
#   `describe "literal string" do` — string describes carry no class binding.
#   `describe Foo.method do` — method-reference describes (`.` or `#`).
#   `describe Foo, "context" do` — Foo is the class; trailing string ignored.
#
# Heuristic limits (regex-only, no parser):
#   - Only the first `describe` token per line is inspected.
#   - Qualified names like `Components::Cache::Cacheable` are looked up by
#     scanning for any of the following declarations in src/:
#       `module X`, `class X`, `class X <`, `struct X`, `record X,`,
#       `abstract class X`, `abstract struct X`, `class X(`, `struct X(`,
#       `lib X`, `enum X`.
#   - We look up only the deepest segment (last `::` component) — a
#     spec describing `Foo::Bar` passes if `Bar` is declared anywhere
#     in src/. This avoids false positives on Crystal's open-module
#     re-opening pattern (`module Foo; module Bar; end; end` in many
#     files).
#
# Known false-negative risk (deliberate, documented):
#   - The deepest-segment heuristic CAN hide namespace drift. If a
#     spec writes `describe UI::OldName` and the class was actually
#     renamed to `Components::OldName` (same leaf, different parent),
#     the rule passes because the leaf still resolves. Full namespace-
#     aware resolution would require an AmberLSP `ProjectContext` or a
#     Crystal parser hook; the runner is intentionally regex-only
#     until/unless that infrastructure exists. The rule catches the
#     common case (typo'd or deleted class names); it does not catch
#     reorg-by-namespace.
#
# Class registry is built lazily on first `check` call and cached on
# the rule instance for the duration of the runner process.
#
# Skipped (false-positive cases):
#   - Fixture trees (`spec/web/lint_conventions/fixtures/` etc.) — the
#     runner's `discover_files` already excludes `/fixtures/`.
#   - Files that don't start with `spec/` (path-scoped rule).

require "../convention_rule"

# Asserts that every `describe <ClassIdent> do` in a spec file
# references a class declared in `src/`.
class SpecDescribeMatchesClassRule < ConventionRule
  # Captures the identifier inside `describe Foo do` or
  # `describe Foo, "..." do`. Trailing strings, method-references,
  # and parenthesized argument forms are ignored by the negative
  # lookahead patterns below.
  DESCRIBE_PATTERN = /^\s*describe\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)(\s*,|\s+do\b|\s*$)/

  # Source-side class/module/struct/enum/lib/record declaration
  # patterns. Each matches at start of (optionally-indented) line so
  # we don't pick up identifiers used inside method bodies. The
  # capture group is the FULL identifier (which may be qualified —
  # e.g. `module UI::AXTest`); we split on `::` after the match and
  # register every segment so a `describe UI::AXTest` query resolves
  # `AXTest` against the source-declared deepest segment.
  DECL_PATTERNS = [
    /^\s*(?:abstract\s+)?class\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)\b/,
    /^\s*(?:abstract\s+)?struct\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)\b/,
    /^\s*module\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)\b/,
    /^\s*enum\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)\b/,
    /^\s*lib\s+([A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*)\b/,
    /^\s*record\s+([A-Z][A-Za-z0-9_]*)\b/,
  ]

  # Directories scanned to build the class registry. Includes src/
  # (canonical), samples/ (Voyager + Amber spike define classes that
  # specs legitimately describe), and spec/web/support/ +
  # spec/native_*/support/ (test helpers like FakeLibObjCBridge and
  # SpecSupport::AccessibilityMatchers are declared in spec helpers
  # AND described by their own spec).
  REGISTRY_ROOTS = [
    "src",
    "samples",
    "spec/web/support",
    "spec/native_macos/support",
    "spec/native_ios/support",
    "spec/native_android/support",
  ]

  @class_registry : Set(String)? = nil

  def rule_name : String
    "family_2/spec_describe_matches_class"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless rel.starts_with?("spec/")
    return diagnostics unless rel.ends_with?("_spec.cr")

    registry = class_registry

    content.each_line.with_index(1) do |line, lineno|
      next unless m = DESCRIBE_PATTERN.match(line)
      ident = m[1]
      # Skip if the rest of the captured tail suggests a method-ref form
      # (`Foo.bar` describe) — the pattern shouldn't match that, but
      # double-check by ensuring no `.` or `#` follows the identifier
      # before the comma / `do`.
      rest_start = line.index(ident, 0).not_nil! + ident.size
      after = line[rest_start, 1]?
      next if after == "." || after == "#"

      deepest = ident.split("::").last
      next if registry.includes?(deepest)

      diagnostics << Diagnostic.new(
        file_path: file_path,
        line: lineno,
        rule_name: rule_name,
        message: "describe '#{ident}' references a class not declared in src/ (looked for any class/module/struct/enum/lib named '#{deepest}')",
        suggested_fix: "rename the describe to a string literal OR declare '#{deepest}' in src/ OR fix the referenced class name"
      )
    end
    diagnostics
  end

  # Lazily builds the set of class/module/struct/enum/lib/record
  # identifiers declared anywhere under `src/`. Cached on the rule
  # instance — the runner keeps one rule instance per process.
  private def class_registry : Set(String)
    cached = @class_registry
    return cached if cached
    set = Set(String).new
    REGISTRY_ROOTS.each do |root|
      next unless Dir.exists?(root)
      Dir.glob("#{root}/**/*.cr") do |path|
        next if path.includes?("/lib/")
        next if path.includes?("/.crystal-cache/")
        next if path.includes?("/fixtures/")
        begin
          File.each_line(path) do |line|
            DECL_PATTERNS.each do |pat|
              if m = pat.match(line)
                # Register the FULL identifier and every segment of a
                # qualified name (e.g. `module UI::AXTest` registers
                # both "UI" and "AXTest" so a `describe UI::AXTest`
                # query resolves on the deepest-segment heuristic).
                m[1].split("::").each { |seg| set << seg }
                set << m[1]
              end
            end
          end
        rescue
          # Unreadable file — skip silently.
        end
      end
    end
    @class_registry = set
    set
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
