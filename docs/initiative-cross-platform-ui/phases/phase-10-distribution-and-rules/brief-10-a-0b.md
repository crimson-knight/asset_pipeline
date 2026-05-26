# Phase 10A.0b — Family 2: View-Spec Pair Rules

**Sub-phase:** 10A.0b — extend the convention runner with view-spec pair rules.
**Branch:** `phase-10-a-0b` cut from `phase-10` (post-trio merge, tag `phase-10-trio-merged-2026-05-26`).
**Status:** v1.
**Predecessor:** 10A.0a + 10C.0 closed (both required: needs the runner + needs the spec/web/ vs spec/native_*/ layout).

---

## Critical context

After 10A.0a + 10C.0 merged, the runner discovers rules from `src/lsp_rules/family_N_*/` and the spec tree is split by platform under `spec/web/`, `spec/native_macos/`, `spec/native_ios/`, `spec/native_android/`.

Family 2 enforces the view-spec pair convention: every `class X < UI::View` in `src/ui/views/` should have a matching spec file at `spec/web/ui/views/x_spec.cr` (or the equivalent platform path when the view is platform-gated).

## 1. What you are doing

Build 3 Family 2 rules under `src/lsp_rules/family_2_view_spec_pair/`:

1. `view_has_spec_rule.cr` — every `class X < UI::View` subclass under `src/ui/views/` must have a corresponding spec file at `spec/web/ui/views/x_spec.cr`. The naming convention: PascalCase class name → snake_case spec file. Tier-3 gated views (e.g. `class ActionSheet ... {% if flag?(:ios) %}`) get their spec at `spec/native_ios/ui/views/action_sheet_spec.cr` (or the matching platform dir). The rule reads the file's macro guards to determine the expected platform dir.
2. `spec_has_view_rule.cr` — the reverse: every `*_spec.cr` under `spec/web/ui/views/` and `spec/native_*/ui/views/` corresponds to a view file. Catches orphaned specs.
3. `spec_describe_matches_class_rule.cr` — every spec file's top-level `describe Foo` block must reference a real class. The rule scans for `describe SomeClass do` and verifies the class exists in the source tree.

Each rule extends `ConventionRule` (auto-discovered by the runner via `inherited` macro). False-positive cases shipped as regression fixtures under `spec/lint_conventions/fixtures/family_2_*/`.

## 2. Read first

1. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/architecture-decisions.md` Decision 1 + 2.
2. `src/lsp_rules/family_1_naming/screen_class_naming_rule.cr` and `view_subclass_under_views_dir_rule.cr` — pattern reference for rule structure.
3. `src/lsp_rules/convention_rule.cr` — base class.
4. `spec/lint_conventions/family_1_naming_spec.cr` — fixture-driven spec pattern.
5. `src/ui/views/_gate_stubs/` — Tier-3 stub pattern; rule must NOT flag the stubs.

## 3. Constraints (Hard Rules)

- Forward commits only on `phase-10-a-0b`.
- Each new rule must: pass green on current source AND fire red on intentional violation.
- False-positive cases: at minimum, gate stubs, abstract base classes (`UI::View` itself), and `_gate_stubs/` files must not trigger.
- `[[codex-as-architect-antagonist]]` applies.

## 4. Deliverables

### Deliverable 1 — `src/lsp_rules/family_2_view_spec_pair/view_has_spec_rule.cr`

Scan `src/ui/views/*.cr` (excluding `_gate_stubs/`). For each `class X < UI::View` or `class X < View` declaration:
- Compute expected spec path: `spec/web/ui/views/<snake_case>_spec.cr` (default).
- If the view file has `{% if flag?(:ios) %}` macro guard at top level: `spec/native_ios/ui/views/<snake_case>_spec.cr`.
- If `flag?(:macos)`: `spec/native_macos/ui/views/<snake_case>_spec.cr`.
- If `flag?(:android)`: `spec/native_android/ui/views/<snake_case>_spec.cr`.
- Check existence with `File.exists?`. Emit Diagnostic if missing.

### Deliverable 2 — `src/lsp_rules/family_2_view_spec_pair/spec_has_view_rule.cr`

Reverse: scan `spec/*/ui/views/*_spec.cr`. For each, compute expected source path. Emit if missing.

### Deliverable 3 — `src/lsp_rules/family_2_view_spec_pair/spec_describe_matches_class_rule.cr`

Scan all spec files. Find `describe SomeClass do` patterns. Verify the referenced class exists in `src/`. Allow `describe "literal string" do` (those don't reference classes). Allow `describe FooBar.method do` (method references).

### Deliverable 4 — Regression fixtures + spec

`spec/lint_conventions/fixtures/family_2_view_spec_pair/`:
- `view_with_spec_pass/` — paired view + spec.
- `view_without_spec_fail/` — view file without spec → rule fires.
- `orphan_spec_fail/` — spec file without view → rule fires.
- `tier3_gated_view_pass/` — view with `{% if flag?(:ios) %}` + spec in `spec/native_ios/ui/views/` → pass.
- `abstract_base_pass/` — abstract class → not flagged.

`spec/web/lint_conventions/family_2_view_spec_pair_spec.cr` — same fixture-driven pattern as family 1 spec.

### Deliverable 5 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-a-0b-close.md`:
- 3 new rules + their green/red status on current source.
- Coverage stats (how many views, how many specs, how many pairs).
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-a-0b phase-10`.
2. Read current view + spec inventory: `find src/ui/views -name '*.cr' | wc -l` and `find spec -name 'views_spec.cr' -o -path '*/views/*_spec.cr' | wc -l`.
3. Build 3 rules iteratively. After each: run `crystal run scripts/lint_conventions.cr`. Must stay green on current source.
4. Add fixtures + spec.
5. `crystal run scripts/lint_conventions.cr` — final check.
6. `crystal spec spec/web/lint_conventions/` — fixture spec pass.
7. Close handoff.
8. Standard footer.

## 6. Acceptance gate

- ✅ `crystal run scripts/lint_conventions.cr` exits 0 (now 9 rules loaded: 5 Family 1 + 1 Family 5 + 3 Family 2).
- ✅ Each new rule fires red on intentional violation (via fixture spec).
- ✅ Tier-3 gated views correctly classified.
- ✅ Codex content review APPROVE.

## 7. Out of scope

- Family 3 (architectural) — 10A.0c.
- Family 4 (test_id hygiene) — 10A.final.
- Family 5 deep rules — 10A.final.
- AmberLSP integration.
- Per-method Crystal doc comments.

— Architect (Claude Opus 4.7), 10A.0b brief v1
