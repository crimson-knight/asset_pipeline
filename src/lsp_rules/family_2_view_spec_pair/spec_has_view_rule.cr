# Phase 10A.0b — Family 2 view-spec pair rule: every view spec maps to a
# source view file.
#
# Reverse of `family_2/view_has_spec`. For every `*_spec.cr` under
# `spec/web/ui/views/`, `spec/native_macos/ui/views/`,
# `spec/native_ios/ui/views/`, and `spec/native_android/ui/views/`,
# verify a paired view file exists at `src/ui/views/<basename>.cr`,
# where `<basename>` is the spec basename minus the `_spec` suffix
# (and minus a known role suffix like `_compile_error`).
#
# Known role suffixes (stripped when computing the candidate source
# basename, in order — the first source-file match wins):
#   `_compile_error`     — Tier-3 macro-guard compile-time fixtures.
#   `_integration`       — multi-view integration specs.
#   `_overrides`         — runtime override specs.
#   `_reactivity`        — re-render lifecycle specs.
#   `_a11y`              — accessibility tree specs.
#
# Skipped (false-positive cases):
#   - Spec files listed in `view_spec_pair.orphan_spec_allowlist` in
#     `.lint_conventions.yml`.
#   - Spec files outside the four `spec/*/ui/views/` directories.

require "../convention_rule"

# Asserts that every `_spec.cr` under `spec/*/ui/views/` has a paired
# `src/ui/views/<basename>.cr` source file (after stripping the
# `_spec` suffix and any known role suffix).
class SpecHasViewRule < ConventionRule
  SPEC_DIRS = [
    "spec/web/ui/views/",
    "spec/native_macos/ui/views/",
    "spec/native_ios/ui/views/",
    "spec/native_android/ui/views/",
  ]

  KNOWN_ROLE_SUFFIXES = [
    "_compile_error",
    "_integration",
    "_overrides",
    "_reactivity",
    "_a11y",
  ]

  @orphan_allowlist : Array(String) = [] of String

  def configure(config : ConventionConfig) : Nil
    @orphan_allowlist = config.view_spec_pair_orphan_spec_allowlist.dup
  end

  def rule_name : String
    "family_2/spec_has_view"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless SPEC_DIRS.any? { |d| rel.starts_with?(d) }
    return diagnostics unless rel.ends_with?("_spec.cr")
    return diagnostics if @orphan_allowlist.includes?(rel)

    spec_basename = File.basename(file_path, ".cr").sub(/_spec$/, "")
    return diagnostics if candidate_source_exists?(spec_basename)

    diagnostics << Diagnostic.new(
      file_path: file_path,
      line: 1,
      rule_name: rule_name,
      message: "Spec '#{rel}' has no paired source file at 'src/ui/views/#{spec_basename}.cr' " \
               "(or with a stripped role suffix: #{KNOWN_ROLE_SUFFIXES.join(", ")})",
      suggested_fix: "create 'src/ui/views/#{spec_basename}.cr' OR rename the spec OR add '#{rel}' " \
                     "to view_spec_pair.orphan_spec_allowlist in .lint_conventions.yml"
    )
    diagnostics
  end

  # True if `src/ui/views/<basename>.cr` exists OR if `<basename>`
  # ends in one of the known role suffixes and stripping it lands on
  # an existing source file. Each strip is non-greedy; the first match
  # wins. Source files under `_gate_stubs/` do NOT count — those are
  # macro stubs, not the canonical view file.
  private def candidate_source_exists?(basename : String) : Bool
    return true if File.exists?("src/ui/views/#{basename}.cr")
    KNOWN_ROLE_SUFFIXES.each do |suffix|
      next unless basename.ends_with?(suffix)
      stripped = basename[0, basename.size - suffix.size]
      return true if File.exists?("src/ui/views/#{stripped}.cr")
    end
    false
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
