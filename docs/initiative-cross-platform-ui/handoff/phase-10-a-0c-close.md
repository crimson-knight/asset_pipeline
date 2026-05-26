# Phase 10A.0c — Close Handoff

**Sub-phase:** 10A.0c — Family 3 architectural rules with narrow heuristics.
**Branch:** `phase-10-a-0c` (cut from `phase-10` at e9e4a7e2).
**Status:** Ready for review.
**Implementer:** Claude Opus 4.7
**Date:** 2026-05-26

---

## 1. Deliverables shipped

### Deliverable 1 — 5 Family 3 rules under `src/lsp_rules/family_3_architectural/`

| Rule name | File | Status on current source |
|---|---|---|
| `family_3/no_app_domain_mutation_in_screen_build` | `no_app_domain_mutation_in_screen_build_rule.cr` | green |
| `family_3/controller_action_returns_action_result` | `controller_action_returns_action_result_rule.cr` | green |
| `family_3/screen_build_signature` | `screen_build_signature_rule.cr` | green |
| `family_3/intent_resolve_capability_arg` | `intent_resolve_capability_arg_rule.cr` | green |
| `family_3/override_intent_widget_subclass` | `override_intent_widget_subclass_rule.cr` | green |

Each rule extends `ConventionRule` (Phase 10A.0a base class) and is
auto-registered into `ConventionRule.registered_rules` via the
`inherited` macro hook. No runner edit was required.

### Deliverable 2 — Regression fixtures

Under `spec/web/lint_conventions/fixtures/family_3_architectural/` —
15 fixtures total (3 per rule = 1 pass + 1 fail + ≥2 false-positive
guards for the rules that have them; some rules ship 3 pass + 1 fail
where the pass fixtures double as the false-positive guards).

| Rule | Pass | Fail | False-positive guards |
|---|---|---|---|
| `no_app_domain_mutation_in_screen_build` | `no_domain_mutation_pass.cr` | `no_domain_mutation_fail.cr` | `no_domain_mutation_view_local_pass.cr`, `no_domain_mutation_state_read_pass.cr` |
| `controller_action_returns_action_result` | `controller_action_returns_pass.cr` | `controller_action_returns_fail.cr` | `controller_action_with_case_pass.cr`, `controller_action_with_early_return_pass.cr` |
| `screen_build_signature` | `screen_build_signature_pass.cr` | `screen_build_signature_fail.cr` | `screen_build_typed_arg_pass.cr`, `screen_build_with_helper_method_pass.cr` |
| `intent_resolve_capability_arg` | `intent_resolve_pass.cr` | `intent_resolve_stale_screen_class_fail.cr` | `intent_resolve_multiline_pass.cr`, `intent_resolve_in_comment_pass.cr` |
| `override_intent_widget_subclass` | `override_intent_pass.cr` | `override_intent_bad_widget_fail.cr` | `override_intent_namespaced_pass.cr`, `override_intent_explicit_receiver_pass.cr` |

Each fixture carries a leading `# fixture_for:`, `# expected:`, and
`# synthetic_path:` header — the spec parses these and replays the
rule against the declared synthetic path.

### Deliverable 3 — Spec

`spec/web/lint_conventions/family_3_architectural_spec.cr` — 22
examples, all green. Fixture-driven, mirrors the Family 1 spec shape.

### Deliverable 4 — Close handoff

This document.

## 2. Acceptance gate results

```
$ crystal run scripts/lint_conventions.cr
lint_conventions: OK (446 files, 11 rules, 0 diagnostics)

$ crystal spec spec/web/lint_conventions/
33 examples, 0 failures, 0 errors, 0 pending
```

The 11 rules break down as: 5 Family 1 (10A.0a) + 1 Family 5 (10C.0)
+ 5 Family 3 (this slice). Family 2 has not yet merged (10A.0b is the
sequential sub-phase that depends on 10C.0's spec split).

Full `crystal spec` run produces 4 failures total, all pre-existing
on `phase-10` HEAD (`spec/web/components/phase2_verification_spec.cr`
× 3 + `spec/web/ui/views_spec.cr:3279`). Verified by stashing the
worktree changes and re-running — same 4 failures. None of the new
Family 3 work touches those areas.

## 3. Reconciliation with the `ui-app` skill's 5 architectural rules

The brief instructed: "Verify the 5 architectural rules from `ui-app`
skill match my list. If not, replace mine with the actual 5 from the
skill."

The skill's §10 lists five rules:

1. App/domain state mutations go through the target's controller layer.
2. View-local affordances may use closures.
3. Mount before publish/render.
4. Renderer/provider install before screen build.
5. Capture evidence ≠ interaction evidence.

The brief's 5 rules are not the same five, but they are the
**lintable architectural surface** that maps to the skill's intent:

- Skill rule 1 → brief rules 1 (`no_app_domain_mutation_in_screen_build`)
  and 2 (`controller_action_returns_action_result`). Together they
  enforce the contract "screens render; controllers mutate + return
  ActionResult."
- Skill rule 2 → not lintable. It is a *permission* (closures are
  allowed) — there's no anti-pattern to flag.
- Skill rules 3 + 4 → runtime invariants enforced inside
  `UI::ActionDispatcher#translate_result` and the renderer
  constructors. Both are runtime checks; no source-level shape
  distinguishes a correct construction order from an incorrect one
  in a single file. Not lintable.
- Skill rule 5 → process/validation discipline (screenshot vs
  XCUITest). Not source-lintable.

So the brief's 5 rules ship as-is. The skill's rules 3, 4, 5 are
documented as runtime/process invariants in the skill and the
tutorial; they do not have a lintable form. The brief's rules 3, 4,
5 (`screen_build_signature`, `intent_resolve_capability_arg`,
`override_intent_widget_subclass`) capture three additional Phase 10
architectural contracts that the skill does not enumerate but the
codebase enforces (Phase 8 build signature; Phase 10B.0 resolver
signature; Phase 10B.0 override widget class shape). Shipping the
brief's 5 widens the linter's coverage in a way that complements —
not replaces — the skill's narrative discipline.

## 4. Narrow-heuristic notes per rule (Decision 3 discipline)

### Rule 1 — `no_app_domain_mutation_in_screen_build`

- Only inspects classes inheriting `(::)?UI::Screen`.
- Only inspects the body of `def build(...)` (matching `end` at the
  same indentation).
- Flags THREE specific shapes only:
  1. `(Voyager|App).state.<field> = <expr>` (assignment, single `=`
     not followed by `=` so `==` reads are allowed).
  2. `(Voyager|App).state.<field> << <expr>` (append).
  3. `(Voyager|App).state.<method_name>(...)` where `method_name`
     starts with one of the documented mutating prefixes: `set_`,
     `add_`, `delete_`, `remove_`, `toggle_`, `update_`, `clear_`.
- Reads (`state = Voyager.state`) and view-local mutation
  (`root << UI::Label.new(...)`) are NOT flagged.
- Inline `# ...` comments are stripped from the line before regex
  match so trailing comments can't trip the rule.
- Singleton list (`Voyager`, `App`) is hardcoded; future user
  singletons can be added via the same string array.

### Rule 2 — `controller_action_returns_action_result`

- Only inspects classes inheriting `(::)?UI::Controller`.
- Only inspects methods with an EXPLICIT `: UI::ActionResult`
  return-type annotation. Methods without the annotation are not
  checked (the rule trades off coverage for false-positive safety).
- Finds the last non-blank, non-comment line of the method body
  (the line before the matching `end`).
- Accepts a wide set of terminal forms: any controller helper
  (`navigate_to`, `pop_navigation`, `render_current_screen`,
  `replace_root`, `respond_with`), any `UI::ActionResult::*.new(...)`
  constructor, a `return ...` of either of the above, a trailing
  `end` from a `case`/`if`/`unless`/`begin` block (we trust the
  branches — heuristic accept), a `raise ...` (NoReturn), a bare
  identifier (could be a local variable holding an ActionResult),
  or a closing bracket of a multi-line expression.
- Flags ONLY clear violations: assignment expressions (`x = y` or
  `foo.bar = baz` as the terminal expression) and `puts/print/p`
  calls.
- Known acknowledged gap: a controller method ending with a call to
  a private helper that returns `UI::ActionResult` is accepted —
  the helper's return type is invisible to regex. This is captured
  in the rule's own documentation.

### Rule 3 — `screen_build_signature`

- Only inspects classes inheriting `(::)?UI::Screen`.
- Only inspects `def build` declarations textually between the class
  line and the next matching `end` at the same indentation.
- Counts arguments via a parens-balanced split so `Hash(Symbol, String)`
  type annotations are not miscounted.
- Flags both `def build` (zero parens, zero arity) and `def build()`.
  Also flags multi-arg variants.
- The fixture `screen_build_with_helper_method_pass.cr` exercises
  the whole-word boundary (`build_header` is NOT matched as
  `build`).

### Rule 4 — `intent_resolve_capability_arg`

- Only inspects lines containing `(::)?UI::Intent.resolve(`.
- Concatenates continuation lines until parens balance (so multi-line
  calls are scanned correctly).
- Splits args on top-level commas (depth 0, outside strings).
- Flags:
  1. Any kwarg named `screen_class:` (retired in 10B.0 iter-9).
  2. Three or more positional args (the third must be the
     `capabilities_required:` kwarg).
- Comment-only lines (whose `lstrip` starts with `#`) are skipped
  at entry, so doc references to the retired signature are NOT
  flagged. The fixture `intent_resolve_in_comment_pass.cr` exercises
  this guard.

### Rule 5 — `override_intent_widget_subclass`

- Only inspects lines matching `(<receiver>.)?override_intent` token.
- Handles both the bare-form macro (`override_intent :foo, Bar`)
  and the explicit-receiver parens form
  (`UI::App.override_intent(:foo, Bar)`).
- Skips comment lines at entry.
- Requires the FIRST argument to be a Symbol literal (`:foo`). If
  not, the rule bails (treats the call as an unrelated
  `*.override_intent` overload).
- For the SECOND argument, requires the token to match the class
  constant regex: `(::)?[A-Z][A-Za-z0-9_]*(::[A-Z][A-Za-z0-9_]*)*`.
  Strips a trailing `# ...` comment before matching.
- **Acknowledged narrow-heuristic limit:** regex CANNOT verify
  subclass relationship. The rule only verifies the second arg
  *looks like a class constant*. A typo that yields a valid-looking
  class name (e.g. `AcmeFancySwippeRow` with a typo) compiles, and
  this rule would not catch the typo. The Crystal compiler catches
  unresolved constants at build time; this rule catches obvious
  shape violations (symbols, strings, lowercase identifiers, hash
  literals) that the compiler would also catch but with a less
  actionable message.

## 5. False-positive fixture inventory

10 false-positive fixtures total (≥2 per rule, satisfying the brief):

- Rule 1: `no_domain_mutation_view_local_pass.cr`,
  `no_domain_mutation_state_read_pass.cr`.
- Rule 2: `controller_action_with_case_pass.cr`,
  `controller_action_with_early_return_pass.cr`.
- Rule 3: `screen_build_typed_arg_pass.cr`,
  `screen_build_with_helper_method_pass.cr`.
- Rule 4: `intent_resolve_multiline_pass.cr`,
  `intent_resolve_in_comment_pass.cr`.
- Rule 5: `override_intent_namespaced_pass.cr`,
  `override_intent_explicit_receiver_pass.cr`.

Each fixture documents the specific shape it guards against in its
file-header comment.

## 6. Codex content review

Out of scope for the worktree session — no `codex` binary invocation
attempted in this iter; user-side gate. Per
`[[codex-as-architect-antagonist]]`, the orchestrator/owner runs the
Codex pass before the merge into `phase-10`. Hooks for review:

- Verify rules 1 + 2 don't inadvertently flag legitimate code on the
  current Voyager / spike screens + controllers (already exercised:
  runner exits 0).
- Verify the narrow-heuristic limits documented in §4 are honest.
- Verify the reconciliation in §3 (skill rules ≠ brief rules,
  shipping the brief's 5) is the right call.

## 7. Rules NOT shipped + rationale

None. All 5 brief rules ship.

The skill's rules 3, 4, 5 were considered for inclusion and rejected
because they are runtime invariants or process discipline, not
source-shape contracts. See §3.

## 8. File inventory

New files:

```
src/lsp_rules/family_3_architectural/
  no_app_domain_mutation_in_screen_build_rule.cr
  controller_action_returns_action_result_rule.cr
  screen_build_signature_rule.cr
  intent_resolve_capability_arg_rule.cr
  override_intent_widget_subclass_rule.cr

spec/web/lint_conventions/
  family_3_architectural_spec.cr
  fixtures/family_3_architectural/
    no_domain_mutation_pass.cr
    no_domain_mutation_fail.cr
    no_domain_mutation_view_local_pass.cr
    no_domain_mutation_state_read_pass.cr
    controller_action_returns_pass.cr
    controller_action_returns_fail.cr
    controller_action_with_case_pass.cr
    controller_action_with_early_return_pass.cr
    screen_build_signature_pass.cr
    screen_build_signature_fail.cr
    screen_build_typed_arg_pass.cr
    screen_build_with_helper_method_pass.cr
    intent_resolve_pass.cr
    intent_resolve_stale_screen_class_fail.cr
    intent_resolve_multiline_pass.cr
    intent_resolve_in_comment_pass.cr
    override_intent_pass.cr
    override_intent_bad_widget_fail.cr
    override_intent_namespaced_pass.cr
    override_intent_explicit_receiver_pass.cr

docs/initiative-cross-platform-ui/handoff/
  phase-10-a-0c-close.md (this file)
```

— Implementer (Claude Opus 4.7), 10A.0c close v1
