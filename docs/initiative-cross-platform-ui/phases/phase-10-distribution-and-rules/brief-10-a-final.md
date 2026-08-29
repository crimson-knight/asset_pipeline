# Phase 10A.final — Full public docs + Family 4 + Family 5 deep rules

**Branch:** `phase-10-a-final` from `phase-10` (will be cut after all preceding Phase 10 work merges).
**Status:** v1. Predecessor: 10A.0a/b/c, 10B.0–10B.5, 10C.0 all closed.

## Context

This is the finishing sweep for Phase 10's developer-experience surface. Three deliverables:

1. **Full public-API Crystal docs** — per-class + per-method documentation for the entire `src/ui/` and `src/asset_pipeline/` public surface (extending the iter 5/6 file headers + per-class summaries from 10A.0a with proper Crystal-doc per-method content).
2. **Family 4 rules** — test_id hygiene. Every interactive widget should have a `test_id` set; specs should reference test_ids consistently; etc.
3. **Family 5 deep rules** — beyond the directory rule from 10C.0. Examples: every native_macos spec file must have `-Dmacos` flag in its description; every spec with macOS-only fixtures must NOT live in `spec/web/`; etc.

## Deliverables

### Deliverable 1 — Full public-API docs

For every public class / module / method / macro in `src/ui/` + `src/asset_pipeline/`:

- **Class / module**: 2-3 sentence summary (already done for most via iter 5/6) + a usage example in the docstring.
- **Public method**: 1-2 sentence description + parameter docs + return doc + example if useful.
- **Public property (getter/setter/property)**: 1-line description.
- **Macro**: explain what it generates + the inputs.

Crystal-doc style — use `#` line comments before the declaration, with markdown for code samples. The compiler's doc generator picks these up.

Priority order (highest-value first):
1. `UI::View` and its 5+5+2+5 properties (accessibility_label, accessibility_hint, ..., accessibility_actions, focused, focusable, tab_index, keyboard_shortcut, etc.).
2. `UI::Intent` API: `resolve`, `dispatch`, `Registry`, `ClassCRegistry`.
3. `UI::App` + `UI::Screen` + `UI::Controller` + `UI::ActionDispatcher` + `UI::ActionResult` + `UI::FormState` + `UI::ScreenContext`.
4. Each `UI::View` subclass in `src/ui/views/` (60+ widgets).
5. Each renderer (`UI::Web::Renderer`, `UI::AppKit::Renderer`, `UI::UIKit::Renderer`, `UI::Android::Renderer`).
6. Design tokens (`UI::DesignTokens::Tokens`, etc.).
7. Environment + Animation.

Don't ship dishonest docs. If a widget's docs would lie about its behavior on a platform, ship honest "limitations" notes.

### Deliverable 2 — Family 4 rules

In `src/lsp_rules/family_4_test_id_hygiene/`:

1. `interactive_widget_test_id_rule.cr` — every interactive widget (Button, TextField, Picker, etc.) instantiated in `src/ui/views/` examples / samples / specs should have `test_id` set. Configurable allowlist for widgets-that-don't-need-it.
2. `spec_test_id_reference_rule.cr` — when a spec asserts on a `test_id`, the asserted value should match a `test_id` actually set somewhere in the test setup.
3. `unique_test_id_per_screen_rule.cr` — within a single Screen's `build` method, no two views should declare the same `test_id`.

False-positive fixtures + regression spec per Family 1-3 pattern.

### Deliverable 3 — Family 5 deep rules

In `src/lsp_rules/family_5_partial/` (extending 10C.0's directory rule):

1. `native_spec_has_platform_flag_rule.cr` — every spec under `spec/native_<X>/` should reference its platform context (e.g., describe block mentions the platform, or spec_helper sets the flag).
2. `cross_target_spec_purity_rule.cr` — spec files under `spec/web/` must NOT reference native-only types (no `UI::AppKit::Renderer` instantiation, no `LibAndroidBridge`, etc.).
3. Optional: more if the audit reveals them.

## Workflow

1. `git checkout -b phase-10-a-final phase-10`.
2. **Deliverable 1 (docs)** is the heaviest. Approach:
   - Generate a list of public types via `crystal docs` (or `grep -rl 'class Foo' src/`).
   - For each: read existing header, expand to per-method docs.
   - Many small commits (one per file family is fine).
3. **Deliverable 2 (Family 4)**: 3 rules with fixtures.
4. **Deliverable 3 (Family 5 deep)**: 2+ rules with fixtures.
5. Run linter + specs after each addition. Lint must remain green.
6. Update `MEMORY.md` / `MASTER_PLAN.md` (if appropriate) to reflect Phase 10's completion.
7. Close handoff with the full sub-phase summary.
8. Standard footer.

## Acceptance

- ✅ Public-API docs coverage measurable (run `crystal docs` and verify the doc HTML is rich, or count classes with docstrings vs without).
- ✅ Family 4 rules (3) + fixtures + spec pass.
- ✅ Family 5 deep rules (2+) + fixtures + spec pass.
- ✅ `crystal run scripts/lint_conventions.cr` green (now ~17+ rules loaded: 5 F1 + 3 F2 + 5 F3 + 3+ F4 + 3+ F5).
- ✅ `crystal spec spec/web/` regression count at baseline.
- ✅ Codex content review APPROVE.

## Out of scope

- HIG validation captures.
- Owner hands-on test (10D).
- New widgets / features.

— Architect (Claude Opus 4.7), 10A.final brief v1
