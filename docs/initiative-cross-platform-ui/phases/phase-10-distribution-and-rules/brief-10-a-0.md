# Phase 10A.0 — LSP Families 1–3 + Skill Substrate + Minimal Docs (DRAFT v1)

**Sub-phase:** 10A.0 — land the development tooling substrate BEFORE widget implementation (10B.1+).
**Branch:** `phase-10-a-0` cut from `phase-10`.
**Status:** DRAFT v1 — pending Codex antagonist.
**Predecessor:** 10-pre.2 closed. Parallel with 10B.0 + 10C.0.

---

## 1. What you are doing

Land the development tooling that 10B widget implementers will USE: AmberLSP rules for asset_pipeline conventions (Families 1–3), skill distribution via shards-alpha, and minimal Crystal doc scaffolding (file headers + module summaries only; full per-method docs defer to 10A.final after API stabilizes).

After 10A.0 closes:
- `src/lsp_rules/family_1_naming/*.cr` — file + class naming rules (~5 rules).
- `src/lsp_rules/family_2_view_spec/*.cr` — view-spec pair rules (~3 rules).
- `src/lsp_rules/family_3_architectural/*.cr` — Phase 8 architectural rules (~5 rules).
- AmberLSP `CustomRule` integration loads asset_pipeline rules when an asset_pipeline shard is detected.
- `.claude/skills/asset_pipeline--lsp-rules/SKILL.md` — documents the rule families for AI agents.
- shards-alpha install audit confirms skills + LSP rules ship cleanly in a scratch consumer project.
- Minimal Crystal doc scaffolding on the ~90 public surface files: file header comment + module summary.

Full public docs + Family 4 (test_id hygiene) + Family 5 deep rules defer to **10A.final** after widget shapes stabilize.

## 2. Read first

Working directory: `/Users/crimsonknight/open_source_coding_projects/asset_pipeline`.

1. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/scoping-10.md` v3 §"10A.0".
2. AmberLSP source: `/Users/crimsonknight/open_source_coding_projects/amber_cli/src/amber_lsp/` — `BaseRule` abstract class, existing 17 rules, `CustomRule` mechanism, `setup:lsp` CLI command.
3. `/Users/crimsonknight/open_source_coding_projects/amber_cli/src/amber_lsp/rules/custom_rule.cr` — loader mechanism.
4. Existing skills: `.claude/skills/` for layout reference.
5. shards-alpha: `/Users/crimsonknight/open_source_coding_projects/shards-alpha/src/docs.cr:23-54` — skill distribution mechanism.
6. Phase 8 architectural rules (from `ui-app` skill): app/domain mutation in build, mount-before-publish, renderer-provider install ordering, controller-action signature, screen-registration-matches-class.
7. CLAUDE.md — Naming Conventions section.

## 3. Constraints (Hard Rules)

- **Forward commits only** on `phase-10-a-0` branch.
- **Public surface = the ~90 files in scope.** Per scoping v3 §"10A.0":
  - All files under `src/ui/views/`
  - `src/asset_pipeline/native_app.cr`, `native_controller.cr`, `action_dispatcher.cr`, `action_result.cr`, `native_context.cr`, `amber_integration.cr`
  - `src/ui/form_state.cr`, `src/ui/views/screen.cr`, `src/ui/design_tokens.cr`
  - Renderer internals + `src/components/` + native bridges are NOT public surface.
- **Minimal docs only.** File header (1-2 sentences on intent) + module/class summary (1-2 sentences). NO per-method docs in 10A.0 — those land in 10A.final.
- **No widget implementation, no widget renames, no catalog edits.**
- **Each LSP rule must fire green on the current asset_pipeline + Voyager source** AND fire red on an intentionally-broken scaffold.
- **The Family 3 architectural rules MUST cross-reference Phase 8's banked memory** (`[[renderer-provider-install-ordering]]`, etc.) so the rationale ships with the rule.
- Per `[[codex-as-architect-antagonist]]`: Codex critiques.
- Per `[[complete-phase-arc-before-review]]`: no owner involvement.
- Per `[[design-amber-first-not-after]]`: this slice INTEGRATES with AmberLSP — prove the `CustomRule` mechanism works on a spike FIRST before writing all the rules.

## 4. Deliverables

### Deliverable 1 — `CustomRule` integration spike

Before writing 13+ rules, prove the loader mechanism works:

1. Read `amber_cli/src/amber_lsp/rules/custom_rule.cr` to understand the loader.
2. Write ONE rule (the simplest: `screen_file_suffix_rule` — every `UI::Screen` subclass file ends in `_screen.cr`).
3. Wire it via `CustomRule`.
4. Verify it loads when AmberLSP starts in an asset_pipeline-shard-using project.
5. Verify it fires green on Voyager (which already follows the convention) AND red on an intentionally-broken file.

If the spike works → proceed to Deliverable 2. If the spike surfaces a `CustomRule` API gap → document gap + decide: extend AmberLSP (out of asset_pipeline scope) OR ship rules as a different distribution mechanism.

### Deliverable 2 — Family 1: File + Naming Structure (~5 rules)

In `src/lsp_rules/family_1_naming/`:

- `screen_file_suffix_rule.cr` — every `UI::Screen` subclass file ends in `_screen.cr`.
- `controller_file_suffix_rule.cr` — every `UI::Controller` subclass file ends in `_controller.cr`.
- `screen_class_naming_rule.cr` — every `UI::Screen` subclass name ends in `Screen`.
- `controller_class_naming_rule.cr` — every `UI::Controller` subclass name ends in `Controller`.
- `view_subclass_under_views_dir_rule.cr` — every `UI::View` subclass lives under `src/ui/views/` (or matches a project-configured opt-in path).

Each: extends `BaseRule`, implements `check(file_path, content)`, emits diagnostics with file:line + message + suggested fix.

### Deliverable 3 — Family 2: View → Spec Pair (~3 rules)

In `src/lsp_rules/family_2_view_spec/`:

- `view_requires_spec_rule.cr` — every `src/ui/views/foo.cr` requires `spec/web/ui/views/foo_spec.cr` OR `spec/native_<X>/ui/views/foo_spec.cr` (10C.0's directory layout). Cross-file lookup via AmberLSP's `ProjectContext`.
- `screen_requires_spec_rule.cr` — every `_screen.cr` requires a `_screen_spec.cr` exercising the `build(ctx)` shape.
- `controller_requires_spec_rule.cr` — every `_controller.cr` requires a `_controller_spec.cr` exercising each action method.

These rules depend on 10C.0's directory layout. If 10C.0 isn't done when 10A.0 runs, document the dependency in close handoff (specs may report false-positives on the old `spec/ui/...` layout temporarily).

### Deliverable 4 — Family 3: Architectural (~5 rules)

In `src/lsp_rules/family_3_architectural/`:

- `no_app_domain_mutation_in_build_rule.cr` — screens' `build(ctx)` MUST NOT call mutating methods on `Voyager.state` or any module-level singleton.
- `mount_before_publish_rule.cr` — direct `coord.push/pop/replace_root/republish` calls outside `ActionDispatcher#translate_result` are flagged.
- `renderer_provider_install_ordering_rule.cr` — `UIKit::Renderer.new` constructed AFTER `screen.build(ctx)` in the same scope is flagged. Cross-reference `[[renderer-provider-install-ordering]]`.
- `controller_action_signature_rule.cr` — every action method on `UI::Controller` subclass accepts `(ctx : UI::ScreenContext::Native)` returns `UI::ActionResult`.
- `screen_registration_matches_class_rule.cr` — every `screen :foo, FooController` in a `UI::App` subclass requires `FooController` to exist + inherit `UI::Controller`.

Each rule's diagnostic message includes the rationale (often a bug Phase 8 hit and fixed).

### Deliverable 5 — Skill: `.claude/skills/asset_pipeline--lsp-rules/`

`SKILL.md` documenting:
- All Family 1–3 rules with one-line summary each.
- How to enable rules in a consumer project (`.amber-lsp.yml` template snippet).
- How a violation appears in the editor (LSP diagnostic).
- Where the rules live in source (`src/lsp_rules/`).

This skill ships via shards-alpha — when a project depends on asset_pipeline, the skill is available to Claude Code in that project's `.claude/skills/`.

### Deliverable 6 — shards-alpha install audit

In a scratch consumer project (create a temp dir):

1. Add asset_pipeline as a dependency.
2. Run `shards-alpha install`.
3. Verify `.claude/skills/asset_pipeline--lsp-rules/SKILL.md` lands.
4. Verify AmberLSP can find the rules (probably via the `lib/` install structure).
5. Document the working install pattern.

If `shards-alpha` doesn't ship skills cleanly, surface to architect.

### Deliverable 7 — Minimal doc scaffolding

For each of the ~90 public surface files:
- Top-of-file comment block: 1-2 sentences on the file's purpose.
- Each public class/module: 1-2 sentence summary preceding the definition.

NO per-method docs. NO param/return/raise docs. NO usage examples.

This is a scaffold for 10A.final to extend. 10A.0 just makes sure every file has a header so 10A.final can find what's missing.

### Deliverable 8 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-a-0-close.md`:

- CustomRule spike result (worked / needed extension).
- Rule list with green/red status on Voyager + scaffold.
- Skill distribution audit (works / needed fix).
- Doc scaffold coverage (N of 90 files have headers).
- Open items for 10A.final.
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-a-0 phase-10`.
2. Run Deliverable 1 (CustomRule spike) FIRST. If broken → architect decision before continuing.
3. Apply Families 1 → 2 → 3 (rules in order). Each rule: green on existing source, red on broken scaffold.
4. Skill (Deliverable 5).
5. shards-alpha install audit (Deliverable 6).
6. Minimal doc scaffold (Deliverable 7).
7. Close handoff (Deliverable 8).
8. Incremental commits per deliverable or per family.
9. Standard footer.

## 6. Acceptance gate

- ✅ CustomRule spike works (or architect-approved alternate distribution).
- ✅ All Family 1–3 rules: green on current asset_pipeline + Voyager source; red on intentional violations.
- ✅ Skill installs correctly via shards-alpha.
- ✅ ~90 public surface files have minimal doc scaffolding (header + module summary).
- ✅ Codex content review APPROVE.

## 7. Out of scope

- Full public docs (10A.final).
- Family 4 (test_id hygiene) — 10A.final.
- Family 5 deep rules — 10A.final. (Family 5 directory-convention rule ships in 10C.0.)
- Widget implementation.
- Catalog edits.
- Owner involvement.

## 8. What success looks like

After 10A.0 closes, a widget implementer working on 10B.1+ writing a new `UI::Foo` view in `src/ui/views/foo.cr` sees the LSP flag immediately if:
- They forgot to write `spec/web/ui/views/foo_spec.cr`.
- The class name doesn't match the file name pattern.
- The view's screen ancestor violates Phase 8 architectural rules.

The framework guides correctness rather than relying on the implementer's memory. shards-alpha distributes the skill so future agents joining a downstream project find the documentation automatically.

— Architect (Claude Opus 4.7), 10A.0 brief v1
