# Phase 10A.0b — Close Handoff

**Sub-phase:** 10A.0b — Family 2 view-spec pair rules.
**Branch:** `phase-10-a-0b` (cut from `phase-10` post-trio merge).
**Status:** CLOSED — all 5 deliverables shipped; runner exits 0 with 9 rules; fixture spec green (25 examples, 0 failures).
**Implementer:** Claude Opus 4.7
**Date:** 2026-05-26

---

## 1. Deliverables shipped

### Deliverable 1 — `src/lsp_rules/family_2_view_spec_pair/view_has_spec_rule.cr`

- 143-line Crystal rule extending `ConventionRule`.
- Pattern matches `class X < View` and `class X < UI::View` declarations.
- **Gate-aware:** scans macro openers (`{% if flag?(:X) %}`), branches (`{% else %}` / `{% elsif %}`), and closers (`{% end %}`) to track an active platform flag stack. Each `{% if %}` pushes a frame holding the platform flag (or nil for non-platform conditions); `{% else %}` / `{% elsif %}` clears the current frame's flag (the else-branch body is NOT under the original `if` flag); `{% end %}` pops. The *deepest* non-nil flag in scope determines the expected spec dir (`spec/native_ios/ui/views/`, `spec/native_macos/ui/views/`, `spec/native_android/ui/views/`) — so nested `{% if flag?(:ios) %}` inside an outer `{% if flag?(:macos) %}` correctly classifies the inner class as iOS-gated. Platform-gated classes also accept the default `spec/web/ui/views/<basename>_spec.cr` path because the 10C.0 classification rule treats `{% if flag?(:X) %}`-gated spec bodies as web-resident when they compile under plain `crystal spec` (the existing tier-3 specs ride this convention).
- **Basename source-of-truth:** the expected spec basename is derived from the view's *file* basename (not from the class name). This is honest about idioms like `class VStack` living in `vstack.cr` → `vstack_spec.cr` (not `v_stack_spec.cr`).
- **False-positive skips:** `src/ui/views/_gate_stubs/`, the abstract base `src/ui/view.cr`, anything not under `src/ui/views/` or `samples/`, and any entry in the `.lint_conventions.yml` allowlist `view_spec_pair.expected_pending`.

### Deliverable 2 — `src/lsp_rules/family_2_view_spec_pair/spec_has_view_rule.cr`

- 86-line Crystal rule extending `ConventionRule`.
- Path-only check: any `*_spec.cr` under the four `spec/<platform>/ui/views/` directories must have a paired `src/ui/views/<basename>.cr`.
- **Role-suffix strips:** before reporting an orphan, the rule attempts to strip known role suffixes from the spec basename and recheck source existence. Supported suffixes (in order): `_compile_error`, `_integration`, `_overrides`, `_reactivity`, `_a11y`. This is how `action_sheet_compile_error_spec.cr` correctly resolves to `src/ui/views/action_sheet.cr`.
- **False-positive escape:** `view_spec_pair.orphan_spec_allowlist` in `.lint_conventions.yml` (empty today; reserved for future cross-class integration specs).

### Deliverable 3 — `src/lsp_rules/family_2_view_spec_pair/spec_describe_matches_class_rule.cr`

- 122-line Crystal rule extending `ConventionRule`.
- Scans every `*_spec.cr` under `spec/` for `describe <Identifier> do` patterns.
- **Class registry:** lazily built on first `check` call, cached on the rule instance for the duration of the runner process. Scans `src/`, `samples/`, and `spec/{web,native_macos,native_ios,native_android}/support/` for `class`, `module`, `struct`, `enum`, `lib`, `record`, and their `abstract` variants. Captures fully-qualified declarations (e.g. `module UI::AXTest`) and registers every segment.
- **Deepest-segment heuristic:** `describe UI::Foo` resolves on the registered set containing `Foo`. Avoids false positives from Crystal's open-module re-opening pattern.
- **Documented false-negative risk:** the deepest-segment heuristic CAN hide namespace drift. A spec writing `describe UI::OldName` where the class was actually renamed to `Components::OldName` (same leaf, different parent) passes because the leaf still resolves. Full namespace-aware resolution would require an AmberLSP `ProjectContext` or a Crystal parser hook; the runner is intentionally regex-only until/unless that infrastructure exists. The rule catches the common case (typo'd or deleted class names); it does not catch reorg-by-namespace.
- **Pass forms:** `describe "literal"`, `describe Foo.method`, `describe Foo#method` — all skipped by regex shape.

### Deliverable 4 — Regression fixtures + spec

Fixtures under `spec/web/lint_conventions/fixtures/family_2/` (14 files):

| Fixture | Rule | Expected |
|---|---|---|
| `view_with_spec_pass.cr` | `family_2/view_has_spec` | pass |
| `view_without_spec_fail.cr` | `family_2/view_has_spec` | fail |
| `gate_stub_skip_pass.cr` | `family_2/view_has_spec` | pass |
| `abstract_base_pass.cr` | `family_2/view_has_spec` | pass |
| `tier3_gated_view_pass.cr` | `family_2/view_has_spec` | pass |
| `tier3_gated_view_else_branch_fail.cr` | `family_2/view_has_spec` | fail (with `spec/web/...` path, NOT `spec/native_ios`) |
| `nested_flag_uses_deepest_fail.cr` | `family_2/view_has_spec` | fail (with `spec/native_ios/...` path, NOT `spec/native_macos`) |
| `spec_with_view_pass.cr` | `family_2/spec_has_view` | pass |
| `orphan_spec_fail.cr` | `family_2/spec_has_view` | fail |
| `compile_error_suffix_pass.cr` | `family_2/spec_has_view` | pass |
| `describe_real_class_pass.cr` | `family_2/spec_describe_matches_class` | pass |
| `describe_phantom_class_fail.cr` | `family_2/spec_describe_matches_class` | fail |
| `describe_string_literal_pass.cr` | `family_2/spec_describe_matches_class` | pass |
| `describe_method_ref_pass.cr` | `family_2/spec_describe_matches_class` | pass |

The two macro-branch fixtures (`tier3_gated_view_else_branch_fail.cr` and `nested_flag_uses_deepest_fail.cr`) exercise the gate detector's else-branch clearing and deepest-flag-wins semantics. They DISCRIMINATE the corrected logic from the old logic via `diagnostic_message_contains` + `diagnostic_message_excludes` header assertions — the fixture spec inspects the rendered diagnostic and asserts the expected path appears (NEW logic) and the wrong path does not (OLD logic). Verified by temporarily restoring the iter-1 rule: both fixtures fail with diagnostic-content mismatches under OLD logic, then pass cleanly under iter-2 logic. Codex iter-2 review (LOW-3) requested this discriminating proof.

Spec: `spec/web/lint_conventions/family_2_view_spec_pair_spec.cr` — 16 examples, 0 failures, 0 errors.

Fixture replay uses a fresh `ConventionConfig.new` (no `.lint_conventions.yml` load), so production allowlists do not bleed into spec behavior.

### Deliverable 5 — This close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-a-0b-close.md`.

---

## 2. Status on current source

```
$ crystal run scripts/lint_conventions.cr
lint_conventions: OK (444 files, 9 rules, 0 diagnostics)
```

| Rule | Green on current source | Red on injection |
|---|---|---|
| `family_2/view_has_spec` | green (75 entries on allowlist) | red ✓ via `view_without_spec_fail.cr` fixture |
| `family_2/spec_has_view` | green | red ✓ via `orphan_spec_fail.cr` fixture |
| `family_2/spec_describe_matches_class` | green | red ✓ via `describe_phantom_class_fail.cr` fixture |

All 9 rules now loaded:
- Family 1: `screen_class_naming`, `screen_file_suffix`, `controller_class_naming`, `controller_file_suffix`, `view_subclass_under_views_dir`.
- Family 2 (new): `view_has_spec`, `spec_has_view`, `spec_describe_matches_class`.
- Family 5 (partial): `spec_platform_directory`.

```
$ crystal spec spec/web/lint_conventions/
27 examples, 0 failures, 0 errors, 0 pending
```

(16 new Family 2 examples + 11 pre-existing Family 1 examples.)

---

## 3. Coverage stats

| Metric | Count |
|---|---|
| `src/ui/views/*.cr` (excl. `_gate_stubs/`) | 79 |
| `spec/*/ui/views/*_spec.cr` | 7 |
| Paired (view ↔ spec) today | 4 unique view sources covered by 7 spec files |
| Views on `view_spec_pair.expected_pending` debt allowlist | 75 |
| Tier-3 gated views (action_sheet, context_menu, path_control) | 3 — `action_sheet.cr` has a direct `spec/web/ui/views/action_sheet_spec.cr` (with internal `{% if flag?(:ios) %}` body guard per the 10C.0 web-spec convention) AND a `_compile_error_spec.cr`. `context_menu.cr` and `path_control.cr` only have `_compile_error_spec.cr` today and are on the `expected_pending` allowlist — direct platform-flag-aware specs for those two are tracked-debt follow-ups (P2 in §5 below). Tier-3 `_with_web_fallback` siblings (3 total) all have direct specs. |

**Pairing breakdown of the 7 existing view specs:**

| Spec file | Source resolution |
|---|---|
| `spec/web/ui/views/action_sheet_spec.cr` | direct → `src/ui/views/action_sheet.cr` |
| `spec/web/ui/views/action_sheet_compile_error_spec.cr` | role-suffix strip `_compile_error` → `action_sheet.cr` |
| `spec/web/ui/views/action_sheet_with_web_fallback_spec.cr` | direct → `src/ui/views/action_sheet_with_web_fallback.cr` |
| `spec/web/ui/views/context_menu_compile_error_spec.cr` | role-suffix strip → `context_menu.cr` |
| `spec/web/ui/views/context_menu_with_web_fallback_spec.cr` | direct → `context_menu_with_web_fallback.cr` |
| `spec/web/ui/views/path_control_compile_error_spec.cr` | role-suffix strip → `path_control.cr` |
| `spec/web/ui/views/path_control_with_web_fallback_spec.cr` | direct → `path_control_with_web_fallback.cr` |

---

## 4. Config extensions

`src/lsp_rules/convention_rule.cr` `ConventionConfig` gained two new properties:

- `view_spec_pair_expected_pending : Array(String)` — paths to views known not to have specs yet (debt tracker; 75 entries today).
- `view_spec_pair_orphan_spec_allowlist : Array(String)` — paths to spec files allowed to not map to a single source (empty today).

`.lint_conventions.yml` extended with the `view_spec_pair:` section. Pre-populated allowlist (75 entries) reflects the actual debt at ToT; documented as Phase 10A.final follow-up work.

---

## 5. Migration plan for the 75 view specs

The allowlist is a tracked-debt mechanism, not permanent. Every entry represents a `src/ui/views/<name>.cr` that ships without a paired `spec/web/ui/views/<name>_spec.cr` (or the platform equivalent). Pairing follow-ups should:

1. Land the spec file at the expected path (basename = view basename + `_spec.cr`).
2. Remove the file's entry from `.lint_conventions.yml`'s `view_spec_pair.expected_pending` in the SAME commit.
3. Rerun `crystal run scripts/lint_conventions.cr` to confirm exit 0.

Prioritization (suggested):
- **P0:** Tier-1 layout primitives (`vstack`, `hstack`, `zstack`, `spacer`, `divider`, `card`, `surface`, `grid`) — these get the most use; specs validate basic structure.
- **P1:** Tier-2 controls (`button`, `text_field`, `slider`, `toggle`, `picker`, `date_picker`, `time_picker`) — interactive surface, highest test value.
- **P2:** Apple-only surfaces (`alert`, `confirmation_dialog`, `popover`, `sheet`, `navigation_stack`) and Tier-3 widgets — specs need platform flag awareness.
- **P3:** Shapes / media / drawing (`circle`, `rectangle`, `canvas`, `path_view`, `video_player`, `web_view`).

Adding a NEW view without a spec must NOT touch the allowlist — landing the spec is part of the same PR. The allowlist is a one-way ratchet that only shrinks.

---

## 6. Architect-antagonist (Codex) review verdict

**Iter 1 (initial close):** NEEDS_WORK with 2 MED + 2 LOW findings.

| Finding | Disposition |
|---|---|
| MED-1 — Close handoff overstated tier-3 coverage (claimed all 3 tier-3 views have direct specs; only `action_sheet` does). | Fixed in iter 2: §3 coverage table now describes the actual state (action_sheet has direct + compile_error; context_menu + path_control are on the allowlist with only compile_error specs). |
| MED-2 — Gate detection didn't handle `{% else %}` / `{% elsif %}` and used outermost flag instead of deepest. Happened to classify the two existing files correctly but was not generally correct. | Fixed in iter 2: `view_has_spec_rule.cr` adds `MACRO_ELSE_PATTERN` + `MACRO_ELSIF_PATTERN`; else/elsif clears the current frame's flag; `active_flag` now uses `flag_stack.compact.last?` (deepest). Two new fixtures (`tier3_gated_view_else_branch_fail.cr`, `nested_flag_uses_deepest_pass.cr`) prove the corrected semantics. Handoff §1 deliverable 1 rewritten. |
| LOW-3 — Fixture coverage too live-tree-dependent; tier-3 fixture only covered the simple action_sheet iOS case. | Addressed in iter 2 by the two new fixtures (above) which exercise the gate detector independently of disk state for the gate logic itself. |
| LOW-4 — Deepest-segment class registry heuristic could hide namespace drift; should be documented as false-negative risk, not equivalent to resolver behavior. | Fixed in iter 2: `spec_describe_matches_class_rule.cr` header now carries a "Known false-negative risk" section; handoff §1 deliverable 3 mirrors it. |

**Iter 2 verdict:** NEEDS_WORK on LOW-3 only — Codex accepted MED-1, MED-2, LOW-4 fixes but flagged that the two new fixtures didn't actually discriminate the corrected gate semantics (both passed under old and new logic without inspecting the diagnostic content). Codex iter-2 quote: *"`tier3_gated_view_else_branch_fail.cr` would fail under both the old and new gate logic because neither default nor native spec exists. `nested_flag_uses_deepest_pass.cr` would also pass under the old outermost-flag logic because platform-gated classes accept the default web spec path."*

**Iter 3 (fixture discrimination):** the fixture spec gained two header keys (`diagnostic_message_contains:`, `diagnostic_message_excludes:`) and the two macro-branch fixtures now pin the corrected diagnostic path. Renamed `nested_flag_uses_deepest_pass.cr` → `nested_flag_uses_deepest_fail.cr` to match its `expected: fail` (the fixture now uses a synthetic path with no spec at any platform location, so the rule fires and the diagnostic content discriminates). Verified by temporarily restoring the iter-1 rule and re-running the spec: both new fixtures fail with diagnostic-content mismatches under OLD logic; pass cleanly under iter-2/3 logic.

**Iter 3 verdict:** to be filled by Codex iter-3 re-review. Goal: APPROVE.

---

## 7. Workflow recap

1. `git checkout -b phase-10-a-0b phase-10` ✓
2. Read view + spec inventory (79 views, 7 specs) ✓
3. Built 3 rules iteratively; `crystal run scripts/lint_conventions.cr` stayed green ✓
4. Added 11 fixtures + spec ✓
5. `crystal run scripts/lint_conventions.cr` → OK 9 rules ✓
6. `crystal spec spec/web/lint_conventions/` → 25 / 0 / 0 ✓
7. Close handoff (this doc) ✓
8. Standard footer on every commit ✓

---

## 8. Forward-only commit log

| Iter | Subject | Files |
|---|---|---|
| 1 | `[Phase 10A.0b iter 1] Family 2 view-spec pair rules + fixtures + spec` | 3 rule files, 12 fixtures, 1 spec, ConventionConfig extension, allowlist YAML, this handoff |
| 2 | `[Phase 10A.0b iter 2] Address Codex MED-1/MED-2/LOW-3/LOW-4` | view_has_spec_rule.cr gate-detection fix (else/elsif + deepest flag), 2 new branch fixtures, false-negative-risk doc, handoff corrections |
| 3 | `[Phase 10A.0b iter 3] Discriminate gate-corrected fixtures via diagnostic-content assertions` | fixture spec gains `diagnostic_message_contains` / `_excludes` headers; both macro-branch fixtures pin the corrected diagnostic path; one renamed to match `expected: fail` |

---

— Implementer (Claude Opus 4.7), 10A.0b close iter 3
