# Phase 10A.final — Family 5 partial rule:
# cross-target spec purity.
#
# Specs under `spec/web/` must NOT reference native-only types. Any
# reference to `UI::AppKit::Renderer`, `UI::UIKit::Renderer`,
# `UI::Android::Renderer`, `LibObjCBridge`, `LibAndroidBridge`, or
# `apsk_*` bridge functions inside a web spec is a sign the spec lives
# in the wrong directory (or imports a platform-only helper that won't
# resolve on a web build).
#
# Symmetrically: specs under `spec/native_macos/` should not reference
# `UI::UIKit::Renderer` or `UI::Android::Renderer`, and so on. This
# rule prevents the "macOS spec accidentally touches an iOS bridge"
# class of bug.
#
# Heuristic (narrow on purpose; we match on identifier text):
#
#   1. Scan only `_spec.cr` files.
#
#   2. Determine the spec's home tree by directory:
#        - `spec/web/`           => forbidden: all native bridges and
#                                   native renderers below.
#        - `spec/native_macos/`  => forbidden: UIKit + Android.
#        - `spec/native_ios/`    => forbidden: AppKit + Android.
#        - `spec/native_android/`=> forbidden: AppKit + UIKit.
#
#   3. Forbidden identifier list per tree:
#        AppKit  -> `UI::AppKit::Renderer`, `LibObjCBridge`, `apsk_`
#        UIKit   -> `UI::UIKit::Renderer`
#        Android -> `UI::Android::Renderer`, `LibAndroidBridge`
#
#      The `apsk_` prefix is the SwiftKit bridge C function family; any
#      bare reference outside a `{% if flag?(:macos) || flag?(:ios) %}`
#      guard would fail to link. We accept the macro-guarded reference
#      as legitimate (the rule's regex is line-based, but lines INSIDE
#      a `{% if ... %}` block are still scanned because the runner
#      doesn't simulate macro state — see false-positive note).
#
# False-positive accommodation:
#
#   - A spec that legitimately needs to reference a native type behind
#     a `{% if flag?(:<plat>) %}` guard cannot be distinguished from a
#     bare reference at the regex level. Such specs should use
#     `# lint:disable=family_5_partial/cross_target_spec_purity` and
#     explain the guard in a comment. Family 1's
#     `view_subclass_under_views_dir_rule` ships the same disable
#     pattern for exactly this reason.

require "../convention_rule"

# Asserts that spec files don't reference renderers / bridges that
# belong to other platform trees.
class CrossTargetSpecPurityRule < ConventionRule
  # Token -> reason (used in the diagnostic message). The tokens are
  # literal substring matches; we don't do word-boundary matching
  # because the `apsk_` family is a prefix.
  APPKIT_TOKENS = [
    "UI::AppKit::Renderer",
    "LibObjCBridge",
  ]

  UIKIT_TOKENS = [
    "UI::UIKit::Renderer",
  ]

  ANDROID_TOKENS = [
    "UI::Android::Renderer",
    "LibAndroidBridge",
  ]

  # Map of spec tree -> array of forbidden token groups. Each group is
  # `{label, [tokens]}` so the diagnostic can name the platform family.
  FORBIDDEN_BY_TREE = {
    "spec/web/" => [
      {"AppKit (macOS)", APPKIT_TOKENS},
      {"UIKit (iOS)", UIKIT_TOKENS},
      {"Android", ANDROID_TOKENS},
    ],
    "spec/native_macos/" => [
      {"UIKit (iOS)", UIKIT_TOKENS},
      {"Android", ANDROID_TOKENS},
    ],
    "spec/native_ios/" => [
      {"AppKit (macOS)", APPKIT_TOKENS},
      {"Android", ANDROID_TOKENS},
    ],
    "spec/native_android/" => [
      {"AppKit (macOS)", APPKIT_TOKENS},
      {"UIKit (iOS)", UIKIT_TOKENS},
    ],
  }

  def rule_name : String
    "family_5_partial/cross_target_spec_purity"
  end

  def check(file_path : String, content : String) : Array(Diagnostic)
    diagnostics = [] of Diagnostic
    rel = repo_relative(file_path)
    return diagnostics unless rel.ends_with?("_spec.cr")

    matching_tree = FORBIDDEN_BY_TREE.keys.find { |t| rel.starts_with?(t) }
    return diagnostics unless matching_tree
    forbidden_groups = FORBIDDEN_BY_TREE[matching_tree]

    content.each_line.with_index(1) do |line, lineno|
      stripped = line.lstrip
      next if stripped.starts_with?("#") # ignore comments
      forbidden_groups.each do |group|
        label = group[0]
        tokens = group[1]
        tokens.each do |token|
          next unless token_matches?(line, token)
          diagnostics << Diagnostic.new(
            file_path: file_path,
            line: lineno,
            rule_name: rule_name,
            message: "Spec under '#{matching_tree}' references " \
                     "#{label} type '#{token}'. The spec belongs in " \
                     "the platform tree that owns the bridge, not in " \
                     "the current tree.",
            suggested_fix: "move the spec under spec/native_<platform>/ " \
                           "matching the bridge, or guard the reference " \
                           "behind `{% if flag?(:<platform>) %}` AND add " \
                           "`# lint:disable=family_5_partial/" \
                           "cross_target_spec_purity` with a rationale"
          )
        end
      end
    end
    diagnostics
  end

  # Checks for `token` in `line` with Crystal-identifier word boundaries
  # on BOTH sides. `LibObjCBridge` must match `LibObjCBridge.foo` and
  # `LibObjCBridge` at EOL, but must NOT match `FakeLibObjCBridge` (left
  # boundary fails) nor `LibObjCBridgeFake` / `LibObjCBridgeSpy` (right
  # boundary fails — without this check, a renamed test double that
  # happens to share the prefix would false-positive).
  #
  # The `::` separator IS allowed on the right (token `LibObjCBridge`
  # in `LibObjCBridge::Symbol` should still trip the rule), so the right
  # boundary check treats `:` as a non-identifier follower the same way
  # `.` and `(` are non-identifier followers.
  private def token_matches?(line : String, token : String) : Bool
    idx = 0
    while (pos = line.index(token, idx))
      left_ok = pos == 0 || !identifier_char?(line[pos - 1])
      end_pos = pos + token.size
      right_ok = end_pos >= line.size || !identifier_char?(line[end_pos])
      if left_ok && right_ok
        return true
      end
      idx = pos + 1
    end
    false
  end

  private def identifier_char?(c : Char) : Bool
    c.alphanumeric? || c == '_'
  end

  private def repo_relative(file_path : String) : String
    return file_path[Dir.current.size + 1..-1] if file_path.starts_with?(Dir.current + "/")
    file_path
  end
end
