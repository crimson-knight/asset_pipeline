# Phase 10C.0 — Family 5 (partial): spec platform-directory convention.
#
# Enforces architecture-decisions.md Decision 5: every spec file under spec/
# lives in spec/web/, spec/native_macos/, spec/native_ios/, OR spec/native_android/.
# The only allowed root file is spec/spec_helper.cr (kept for backwards-compat).
#
# This rule ships ahead of Phase 10A.0a's runner (Decision 1: Crystal-side
# convention runner, NOT AmberLSP). Until 10A.0a merges, the rule file exists
# but is not yet wired into a runner — `scripts/lint_conventions.cr` doesn't
# exist on `phase-10` yet. Coordination note in
# `docs/initiative-cross-platform-ui/handoff/phase-10-c-0-close.md`.
#
# Once 10A.0a lands its `ConventionRule` base class at
# `src/lsp_rules/convention_rule.cr` (or equivalent), this file becomes:
#
#   require "../convention_rule"
#
#   class SpecPlatformDirectoryConvention < ConventionRule
#     # ...
#   end
#
# Today the file stands alone — the rule class hand-defines the diagnostic
# shape that 10A.0a is expected to formalize. When the runner merges, only
# the parent class change is needed.

# Lightweight diagnostic record (placeholder shape; 10A.0a finalizes).
struct ConventionDiagnostic
  getter file_path : String
  getter line : Int32
  getter rule_name : String
  getter message : String
  getter suggested_fix : String

  def initialize(@file_path, @line, @rule_name, @message, @suggested_fix)
  end

  def format : String
    "#{@file_path}:#{@line}: [#{@rule_name}] #{@message}\n  fix: #{@suggested_fix}"
  end
end

# Rule: every spec file lives in spec/web/, spec/native_macos/,
# spec/native_ios/, OR spec/native_android/. The only allowed root spec file
# is spec/spec_helper.cr.
#
# This class is a forward-compatible shim for Phase 10A.0a's
# `ConventionRule` base class. The runner will:
#   1. Discover all *.cr files under spec/.
#   2. For each file, call `check(file_path, content)`.
#   3. Aggregate diagnostics and exit non-zero if any are returned.
class SpecPlatformDirectoryConvention
  RULE_NAME = "family_5_partial.spec_platform_directory_convention"

  ALLOWED_DIRS = [
    "spec/web/",
    "spec/native_macos/",
    "spec/native_ios/",
    "spec/native_android/",
  ]

  ALLOWED_ROOT_FILES = [
    "spec/spec_helper.cr",
  ]

  # `content` is provided by the runner for parity with other rules
  # (Family 1, 2, 3 read content). This rule is path-based only.
  def check(file_path : String, content : String? = nil) : Array(ConventionDiagnostic)
    return [] of ConventionDiagnostic unless file_path.starts_with?("spec/")
    return [] of ConventionDiagnostic unless file_path.ends_with?(".cr")
    return [] of ConventionDiagnostic if ALLOWED_ROOT_FILES.includes?(file_path)
    return [] of ConventionDiagnostic if ALLOWED_DIRS.any? { |d| file_path.starts_with?(d) }

    [
      ConventionDiagnostic.new(
        file_path: file_path,
        line: 1,
        rule_name: RULE_NAME,
        message: "Spec file lives outside the platform-aware tree. " \
                 "Every spec must be in spec/web/, spec/native_macos/, " \
                 "spec/native_ios/, or spec/native_android/.",
        suggested_fix: "Move this spec to the appropriate platform directory. " \
                       "See architecture-decisions.md Decision 5 + " \
                       "docs/initiative-cross-platform-ui/handoff/phase-10-c-0-spec-inventory.md " \
                       "for the classification rule (deepest platform dependency).",
      ),
    ]
  end
end
