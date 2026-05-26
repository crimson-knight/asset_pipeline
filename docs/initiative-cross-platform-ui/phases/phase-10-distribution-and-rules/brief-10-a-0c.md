# Phase 10A.0c — Family 3: Architectural Rules with Narrow Heuristics

**Sub-phase:** 10A.0c — 5 architectural rules from the `ui-app` skill.
**Branch:** `phase-10-a-0c` cut from `phase-10` (tag `phase-10-trio-merged-2026-05-26`).
**Status:** v1.
**Predecessor:** 10A.0a closed (needs the runner + `ConventionRule` base).

---

## Critical context

Per **architecture-decisions.md Decision 3**: Family 3 rules must use narrow regex/string-level heuristics. Don't claim AST certainty. Every known false-positive case ships as a regression fixture BEFORE widening rule scope.

## 1. What you are doing

Ship 5 Family 3 architectural rules under `src/lsp_rules/family_3_architectural/`:

1. `no_app_domain_mutation_in_screen_build_rule.cr` — `class X < UI::Screen` ... `def build(ctx)` body must NOT contain known domain singleton mutations (`Voyager.state.foo = ...`, `App.state.bar = ...`). View-local mutation (on locals created inside build) is allowed.
2. `controller_action_returns_action_result_rule.cr` — `class X < UI::Controller` action methods (those decorated with `action_handler :method_name` or whose return type is declared `UI::ActionResult`) must end with a return of an `ActionResult::*` subtype. Catches "controller method returns Nil by accident."
3. `screen_build_signature_rule.cr` — every `class X < UI::Screen` must declare `def build(ctx)` (or `def build(ctx : ScreenContext)`), not `def build()` or other arity.
4. `intent_resolve_capability_arg_rule.cr` — calls to `UI::Intent.resolve(...)` must use the new signature: `resolve(intent_id, context, capabilities_required: ...)` — flag callers passing positional 3rd arg or using removed `screen_class:` kwarg.
5. `override_intent_widget_subclass_rule.cr` — `override_intent :foo, Bar` calls (app or screen scope) must reference a class that subclasses `UI::View`. Flags typos / wrong class.

Each rule: narrow regex pattern, false-positive fixtures pre-committed, Voyager + asset_pipeline source passes green.

## 2. Read first

1. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/architecture-decisions.md` Decision 3 (CRITICAL — narrow heuristics, false positives as fixtures FIRST).
2. `.claude/skills/ui-app/SKILL.md` — the 5 architectural rules canon. Verify the 5 above match. If they don't, replace mine with the actual 5 from the skill.
3. `src/lsp_rules/family_1_naming/*.cr` — pattern reference.
4. `src/lsp_rules/convention_rule.cr` — base class.
5. `src/asset_pipeline/amber_integration.cr` — Screen build signature reference.
6. `src/asset_pipeline/action_dispatcher.cr` + `src/asset_pipeline/native_controller.cr` — Controller pattern reference.
7. `src/ui/intent.cr` — current resolve signature.

## 3. Constraints (Hard Rules)

- Forward commits only on `phase-10-a-0c`.
- Each rule MUST pass green on current asset_pipeline + Voyager source before close.
- Each rule MUST have ≥2 false-positive fixtures committed BEFORE the rule activates.
- Don't claim AST-level certainty in code or docs.
- `[[codex-as-architect-antagonist]]` applies.

## 4. Deliverables

### Deliverable 1 — 5 rules in `src/lsp_rules/family_3_architectural/`

Per the list above. Each rule:
- Extends `ConventionRule`.
- Regex/string-level scan (no AST).
- Emits Diagnostic with file:line + rule_name + message + suggested_fix.

### Deliverable 2 — Regression fixtures

Under `spec/lint_conventions/fixtures/family_3_architectural/`:
- One pass + one fail fixture per rule (5 + 5 = 10 minimum).
- Plus the false-positive fixtures for each rule (≥2 per rule = 10 minimum). Examples:
  - `no_domain_mutation_view_local_pass.cr` — `def build(ctx)` with `local = []; local << ...` → pass.
  - `controller_action_with_early_return_pass.cr` — controller method with early `return ActionResult::Pop.new` → pass.

### Deliverable 3 — Spec

`spec/web/lint_conventions/family_3_architectural_spec.cr` — fixture-driven pattern matching Family 1 + 2 specs.

### Deliverable 4 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-a-0c-close.md`:
- 5 new rules; status on current source.
- False-positive fixture inventory (per rule).
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-a-0c phase-10`.
2. Verify the 5 architectural rules from `ui-app` skill match my list. If not, replace.
3. Build rules one at a time. After each: run `crystal run scripts/lint_conventions.cr` on full repo. MUST stay green. If a rule fires red on existing code, EITHER fix the existing code (if it's a real violation) OR widen the rule's allowed cases via fixture (if false positive).
4. Add fixtures + spec.
5. Close handoff.
6. Standard footer.

## 6. Acceptance gate

- ✅ `crystal run scripts/lint_conventions.cr` exits 0 on current source (now 14 rules loaded if Family 2 has also merged; otherwise 11 = 5 Family 1 + 1 Family 5 + 5 Family 3).
- ✅ Each rule fires red on intentional violation.
- ✅ False-positive fixtures committed before activation.
- ✅ Codex content review APPROVE.

## 7. Out of scope

- Family 4 (test_id hygiene) — 10A.final.
- Family 5 deep rules — 10A.final.
- AmberLSP integration.
- AST-level analysis.
- Widget implementation.

— Architect (Claude Opus 4.7), 10A.0c brief v1
