# Phase 10A.final — Family 5 partial rule:
# native specs must declare their platform context.
#
# Every spec under `spec/native_macos/`, `spec/native_ios/`, or
# `spec/native_android/` should declare its platform context by
# guarding its top-level code (or at least the `describe` block) with
# `{% if flag?(:<platform>) %}`. Without that guard, the spec compiles
# unconditionally and either:
#   - fails to compile on the wrong platform (because it references
#     types only available with a `-D<platform>` flag), or
#   - succeeds on the wrong platform but exercises nothing meaningful.
#
# Heuristic (narrow on purpose; we don't simulate macro expansion):
#
#   1. Scan only `_spec.cr` files under `spec/native_<platform>/`.
#
#   2. For each file, read the directory name to identify the platform
#      slug (`macos` / `ios` / `android`). Allow either:
#        - `{% if flag?(:<platform>) %}` anywhere in the file, OR
#        - `{% if flag?(:macos) || flag?(:ios) %}` (and similar OR
#          combinations) covering the file's platform, OR
#        - a `require ".../spec_helper"` whose helper IS known to set
#          the appropriate flag (we accept the require as evidence).
#
#   3. If neither the inline flag guard nor a recognized helper require
#      is present, emit a diagnostic on line 1.
#
# False-positive accommodation:
#
#   - `lint:disable=family_5_partial/native_spec_has_platform_flag`
#     per-file disable for specs that intentionally want to run on
#     every platform but happen to live under a native subtree (rare).

require "../convention_rule"

# Asserts that every spec under `spec/native_<platform>/` declares its
# platform context.
class NativeSpecHasPlatformFlagRule < ConventionRule
  # Mapping of native directory slug -> the set of acceptable
  # `flag?(:<plat>)` symbols that count as a platform-context
  # declaration for that tree.
  PLATFORM_FLAGS = {
    "spec/native_macos/"   => ["macos"],
    "spec/native_ios/"     => ["ios"],
    "spec/native_android/" => ["android"],
  }

  # Spec-helper file names that we accept as platform-context evidence
  # (i.e. they are known to set or assert the appropriate platform
  # flag before the spec body runs).
  ACCEPTED_HELPER_BASENAMES = [
    "native_spec_helper",
    "macos_spec_helper",
    "ios_spec_helper",
    "android_spec_helper",
  ]

  FLAG_PATTERN = /\bflag\?\(\s*:([a-z_]+)\s*\)/

  def rule_name : String
    "family_5_partial/native_spec_has_platform_flag"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless rel.ends_with?("_spec.cr")

    matching_dir = PLATFORM_FLAGS.keys.find { |d| rel.starts_with?(d) }
    return diagnostics unless matching_dir
    acceptable_flags = PLATFORM_FLAGS[matching_dir]

    return diagnostics if content_has_acceptable_flag?(content, acceptable_flags)
    return diagnostics if content_requires_accepted_helper?(content)

    diagnostics << Diagnostic.new(
      file_path: file_path,
      line: 1,
      rule_name: rule_name,
      message: "Native spec under '#{matching_dir}' has no platform " \
               "context. Expected `{% if flag?(:#{acceptable_flags.first}) %}` " \
               "(or a require of a known native spec_helper). Without " \
               "the guard, the spec compiles on every platform and " \
               "either fails to compile or exercises nothing.",
      suggested_fix: "wrap the file (or the describe block) in " \
                     "`{% if flag?(:#{acceptable_flags.first}) %} ... {% end %}`"
    )
    diagnostics
  end

  # Scans non-comment lines for any `flag?(:<plat>)` declaration where
  # `<plat>` is in `acceptable_flags`. Comment lines are excluded so a
  # fixture's documentation block (which may quote `flag?(:ios)` in
  # English) doesn't suppress the rule.
  private def content_has_acceptable_flag?(content : String, acceptable_flags : Array(String)) : Bool
    content.each_line do |line|
      next if line.lstrip.starts_with?("#")
      line.scan(FLAG_PATTERN) do |m|
        return true if acceptable_flags.includes?(m[1])
      end
    end
    false
  end

  private def content_requires_accepted_helper?(content : String) : Bool
    content.each_line do |line|
      stripped = line.strip
      next unless stripped.starts_with?("require")
      ACCEPTED_HELPER_BASENAMES.each do |helper|
        return true if stripped.includes?(helper)
      end
    end
    false
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
