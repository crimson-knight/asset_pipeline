# Phase 10A.0a — Close Handoff

**Sub-phase:** 10A.0a — Crystal-side convention runner + Family 1 naming rules + skill + minimal doc scaffolding.
**Branch:** `phase-10-a-0a`
**Status:** ACCEPTANCE GATE — pending Codex content review.
**Implementer:** Claude Opus 4.7
**Date:** 2026-05-25

---

## 1. Deliverables shipped

### Deliverable 1 — Runner: `scripts/lint_conventions.cr`
- 165-line Crystal program.
- Walks `src/`, `samples/`, `spec/` by default; excludes `lib/`, `.crystal-cache/`, `spec/fixtures/`.
- CLI options: `--rules=family_N`, `--paths=…`, `--no-default-paths`, `--format=human|machine`, `--quiet`, `--help`.
- Output format: `<file>:<line>: [<rule_name>] <message> (suggested: <fix>)`.
- Exit codes: `0` clean, `1` diagnostics, `2` bad CLI.
- Supports per-file `# lint:disable=<rule>` and `# lint:disable=all` suppression.

### Deliverable 2 — Base class: `src/lsp_rules/convention_rule.cr`
- Abstract class `ConventionRule` with `rule_name : String` and `check(file_path, content) : Array(Diagnostic)`.
- `Diagnostic` struct with `to_s(io)` rendering to the runner's stable line format.
- Helpers: `find_line`, `snake_case`.

### Deliverable 3 — Family 1 (5 naming rules)
All under `src/lsp_rules/family_1_naming/`:

| Rule name | Status on current source | Red on injection |
|---|---|---|
| `family_1/screen_class_naming` | green | red ✓ |
| `family_1/screen_file_suffix` | green | red ✓ |
| `family_1/controller_class_naming` | green | red ✓ |
| `family_1/controller_file_suffix` | green | red ✓ |
| `family_1/view_subclass_under_views_dir` | green | red ✓ |

Injection test placed five intentional violations under `/tmp/lint_violations/`; the runner exited 1 and emitted one diagnostic per violation.

### Deliverable 4 — Skill: `.claude/skills/asset_pipeline--lint-conventions/SKILL.md`
- 135-line guide covering: invocation, exit codes, options, suppression, rule families, adding a rule, CI integration, pre-commit hook, distribution, rationale.

### Deliverable 5 — shards install audit
Created `/tmp/scratch_consumer/` with `asset_pipeline` as a path-dependency; ran shards-alpha's `bin/shards install` (`Shards Alpha 2025.11.25.3` — local checkout at `/Users/crimsonknight/open_source_coding_projects/shards`, the version with AI-docs auto-install). Result:

```
I: Installed AI docs for asset_pipeline (17082 files)
```

Skill landed at `/tmp/scratch_consumer/.claude/skills/asset_pipeline--asset_pipeline--lint-conventions/SKILL.md`.

**Naming note — double-prefix:** The shards installer namespaces every shard skill under `<shard_name>--<source_dir_name>/`. Because the brief specified the source directory as `.claude/skills/asset_pipeline--lint-conventions/`, the installed path becomes `asset_pipeline--asset_pipeline--lint-conventions/`. The SKILL.md is unaffected; consumers see the skill but the directory name is doubly prefixed. A follow-up could rename the source dir to `.claude/skills/lint-conventions/` so the installed path collapses to `asset_pipeline--lint-conventions/`. Deferred until owner ruling.

**Codex MED-5 correction respected:** the audit used `shards`, not `shards-alpha`. The user's homebrew install of the upstream `shards 0.20.0` lacks AI-docs auto-install; the local `shards` checkout at `/Users/crimsonknight/open_source_coding_projects/shards` is shipping that feature and was used to verify installation.

### Deliverable 6 — Minimal doc scaffolding (~90 files)
Idempotent scaffolder at `scripts/scaffold_doc_headers.cr` swept the public surface:

| Surface | Files | Modified |
|---|---|---|
| `src/ui/views/*.cr` | 79 | 78 (one already had a header) |
| `src/asset_pipeline/*.cr` | 11 | 5 (six already had headers) |
| `src/ui/design_tokens.cr` | 1 | 1 |
| `src/ui/form_state.cr` | 1 | 0 (already had a header) |
| **Total** | **92** | **84** |

Each file received:
- 2-line file header (1-2 sentence purpose + part-of-asset_pipeline anchor).
- 1-line class summary inserted above each public `class X < View` declaration that did not already have a `#` comment on the preceding line.

NO per-method docs. NO param/return docs. Deferred to 10A.final.

Idempotency was verified: running the scaffolder a second time scaffolds 0 files.

### Deliverable 7 — Close handoff
This document.

## 2. Runner invocation + exit codes verified

```
$ crystal run scripts/lint_conventions.cr
lint_conventions: OK (433 files, 5 rules, 0 diagnostics)
$ echo $?
0

$ crystal run scripts/lint_conventions.cr -- --no-default-paths --paths=/tmp/lint_violations
…5 diagnostics, one per rule…
lint_conventions: FAIL (5 files, 5 rules, 5 diagnostics)
$ echo $?
1

$ crystal run scripts/lint_conventions.cr -- --bogus-option
lint_conventions: unknown option '--bogus-option'
$ echo $?
2
```

## 3. Voyager / spike adjustments

Two pre-existing samples violated the file-suffix rule and were adjusted in iter-2:

- `samples/initiative-cross-platform-ui-voyager/screens/{settings,sign_in,todos,todo_editor}.cr` were renamed to `*_screen.cr` via `git mv`; `samples/initiative-cross-platform-ui-voyager/app.cr` requires updated.
- `samples/phase-08b-native-spike/src/spike_app.cr` is a deliberate single-file demo that declares multiple screens and controllers; received a `# lint:disable=family_1/screen_file_suffix,family_1/controller_file_suffix` banner with an inline justification.

## 4. Branch / commit summary

```
a4894779 [Phase 10A.0a iter 3] Doc-scaffold sweep across ~90 public surface files
00642af1 [Phase 10A.0a iter 2] Rename voyager screens + disable spike to satisfy Family 1
4f42ed51 [Phase 10A.0a iter 1] Convention rule runner + 5 Family 1 naming rules + skill
f40f247e [Phase 10] Parallel-trio briefs v2 + architecture-decisions.md  (base)
```

3 commits on `phase-10-a-0a` over the phase-10 base. Standard `Co-Authored-By: Claude Opus 4.7` footer on each.

## 5. Acceptance gate

- ✅ `crystal run scripts/lint_conventions.cr` exits 0 on current asset_pipeline + Voyager source (433 files, 5 rules, 0 diagnostics).
- ✅ Each of the 5 Family 1 rules fires RED on an intentional injection.
- ✅ Skill installs correctly via shards in scratch project (double-prefix caveat noted).
- ✅ Minimal doc scaffolding on the 92 public files (per scoping v3 corrected count).
- ⏳ Codex content review APPROVE — pending.

## 6. Out of scope for 10A.0a (per brief §7)

- Family 2 (view-spec pair) — 10A.0b after 10C.0.
- Family 3 (architectural) — 10A.0c after 10A.0a.
- Family 4 (test_id hygiene) — 10A.final.
- Family 5 directory rule — ships in 10C.0; deep rules in 10A.final.
- AmberLSP integration of any kind.
- Per-method Crystal doc comments — 10A.final.

## 7. Notes for the next implementer

- The runner is invoked from the **repo root** (it uses repo-relative `require "../src/lsp_rules/…"`). When wiring CI in 10C.0, the working directory must be the repo root.
- Future families add a rule by: (1) dropping `src/lsp_rules/family_<N>_<topic>/<name>_rule.cr`, (2) `require`-ing it in `scripts/lint_conventions.cr`, (3) appending the rule instance to `load_rules`.
- The double-prefix naming caveat (Deliverable 5) is the cleanest follow-up to address. Renaming `.claude/skills/asset_pipeline--lint-conventions/` → `.claude/skills/lint-conventions/` collapses the installed path. The brief explicitly named the directory with the prefix; this handoff records the consequence so the owner can rule.
- Working-tree coordination: while implementing 10A.0a, the parallel 10B.0 worktree (`asset_pipeline-10c`) and the 10B.0 agent both operated against the same repo. A safer pattern for future parallel sub-phases is per-branch worktrees under distinct paths so untracked files don't get caught in cross-branch `git checkout` races.

— Implementer (Claude Opus 4.7), phase-10-a-0a iter 3 close
