# Phase 10C.0 — Spec Directory Split + Runner Matrix + Family 5 Directory Rules (DRAFT v1)

**Sub-phase:** 10C.0 — establish multi-target spec structure + discover native compile matrix BEFORE widget code lands in 10B.1+.
**Branch:** `phase-10-c-0` cut from `phase-10`.
**Status:** DRAFT v1 — pending Codex antagonist.
**Predecessor:** 10-pre.2 closed. Parallel with 10A.0 + 10B.0.

---

## 1. What you are doing

Reorganize the `spec/` tree into platform-aware directories (`spec/web/` + `spec/native_<X>/` per scoping v3's Convention B). Build per-platform test runners. Discover the actual state of the native compile matrix (iOS, Android) — this is exploration work that Phase 4 nominally established but no one has run end-to-end since. Land Family 5's directory-convention LSP rule (the only Family 5 rule that can land before widget code exists).

After 10C.0 closes, the framework has:
- `spec/web/` (default; runs with `crystal spec`).
- `spec/native_macos/` (runs with `crystal-alpha spec -Dmacos ...`).
- `spec/native_ios/` (runs with `crystal-alpha spec -Dios ...` IF iOS compile works; if broken, documented).
- `spec/native_android/` (runs with `crystal-alpha spec -Dandroid ...` IF Android works; if broken, documented).
- `make test-web`, `make test-macos`, `make test-ios`, `make test-android`, `make test-all` (or shell equivalents).
- `docs/initiative-cross-platform-ui/native-compile-matrix.md` — exact commands, link flags, expected-failure documentation, CI feasibility.
- `src/lsp_rules/family_5_partial/spec_platform_directory_convention.cr` — flags spec files outside the convention.
- Updated `.github/workflows/initiative-cross-platform-ui.yml` to run all feasible platform targets.

## 2. Read first

Working directory: `/Users/crimsonknight/open_source_coding_projects/asset_pipeline`.

1. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/scoping-10.md` v3 §"10C.0".
2. `CLAUDE.md` — Build & Test section, Cross-platform UI initiative CI section.
3. `[[project_platform_minimums]]` memory — macOS 14+, iOS 16+, Phase 4 deployment targets.
4. `[[reference_agent_crystal]]` memory — `crystal-alpha` is now `acrystal` from `crimson-knight/homebrew-agent-crystal`.
5. Current `spec/` tree: `ls spec/` to see what exists.
6. Existing CI: `.github/workflows/initiative-cross-platform-ui.yml`.
7. Existing native build flags: search `src/` for `flag?(:ios)`, `flag?(:macos)`, `flag?(:android)`.
8. `Makefile` (if exists) for current test invocation patterns.

## 3. Constraints (Hard Rules)

- **Forward commits only** on `phase-10-c-0` branch.
- **Don't break existing tests.** `crystal spec` (current default) must still work after the reorg. Map every existing spec to its new home; verify count before/after.
- **Document, don't repair.** If native iOS / Android compile is broken, DOCUMENT the breakage in `native-compile-matrix.md`. Repair is out of scope for 10C.0 (could be a future phase finding).
- **No spec deletions** — only moves. Every existing spec file ends up in the new tree.
- **The LSP rule is read-only at startup** (it lints, doesn't move files).
- Per `[[codex-as-architect-antagonist]]`: Codex critiques.
- Per `[[complete-phase-arc-before-review]]`: no owner involvement.
- Per `[[plan-what-to-understand-not-just-what-to-build]]`: do the discovery work properly. If iOS compile is broken, surface WHY and what would be needed to fix.

## 4. Deliverables

### Deliverable 1 — Spec inventory + classification

Before moving anything, write `docs/initiative-cross-platform-ui/handoff/phase-10-c-0-spec-inventory.md`:

For every spec file under `spec/`:
- Current path.
- Target path (`spec/web/`, `spec/native_macos/`, etc.).
- Why this classification (e.g., file uses `flag?(:macos)` → `spec/native_macos/`; pure Crystal logic with no platform flag → `spec/web/`).
- Any dependencies that affect classification.

This is the move plan. Architect can review/approve before the actual moves happen.

### Deliverable 2 — Spec directory reorganization

Apply the moves from Deliverable 1's inventory.

- Use `git mv` to preserve history.
- Update `spec/spec_helper.cr` if it has any path-relative includes that break.
- Run `crystal spec spec/web/` after the moves — must pass.
- Run `crystal-alpha spec spec/native_macos/ -Dmacos --link-flags="..."` (canonical macOS spec command — derive from existing make targets or CLAUDE.md) — must pass.
- Document any breakage in close handoff.

### Deliverable 3 — Per-platform test runners

Create or extend `Makefile`:

```makefile
test-web:
	crystal spec spec/web/

test-macos:
	crystal-alpha spec spec/native_macos/ -Dmacos --link-flags="-framework AppKit -framework Foundation -lobjc lib/asset_pipeline/src/ui/native/objc_bridge.o"

test-ios:
	crystal-alpha spec spec/native_ios/ -Dios --link-flags="..."  # or document why this fails

test-android:
	crystal-alpha spec spec/native_android/ -Dandroid --link-flags="..."  # or document why this fails

test-all: test-web test-macos
	@echo "iOS/Android: see docs/initiative-cross-platform-ui/native-compile-matrix.md"
```

Adjust target details based on what `Deliverable 4` discovers.

### Deliverable 4 — Native compile matrix discovery

This is exploration. Write `docs/initiative-cross-platform-ui/native-compile-matrix.md`:

For each platform:
- Exact build/spec command.
- Required link flags (frameworks, ObjC bridge .o file, etc.).
- Crystal compiler version requirement (`crystal-alpha` / `acrystal` per `[[reference_agent_crystal]]`).
- Whether builds work TODAY (run the command; report).
- If builds DON'T work: what's the error? Is it Crystal compiler limitation, missing dependency, framework issue, or just an untested path?
- CI feasibility: can this run on GitHub Actions? What runner? What costs?

Specifically:
- macOS: per `[[project_platform_minimums]]` should work; verify.
- iOS: per Phase 4 should work; verify.
- Android: status uncertain; verify.

If iOS or Android is broken: the platform is documented "deferred" with a clear path to fix. NOT a 10C.0 blocker.

### Deliverable 5 — Family 5 directory-convention LSP rule

`src/lsp_rules/family_5_partial/spec_platform_directory_convention.cr`:

Rule: every spec file MUST live in one of:
- `spec/web/`
- `spec/native_macos/`
- `spec/native_ios/`
- `spec/native_android/`
- `spec/spec_helper.cr` (the helper file itself is allowed at root)

Any spec outside these paths is flagged with a diagnostic pointing to the convention doc.

The rule extends `AmberLSP::Rules::BaseRule`. Loadable via the `CustomRule` mechanism (will be wired in 10A.0; 10C.0 just ships the rule file).

Other Family 5 deep rules (cross-file analysis: flag-gated-block-requires-platform-spec, XCUITest-match, AXTest-match, CI-workflow-rule) stay deferred to 10A.final after widget examples exist.

### Deliverable 6 — CI workflow update

`.github/workflows/initiative-cross-platform-ui.yml`:

- Matrix-strategy job that runs all feasible platforms.
- iOS / Android jobs document `continue-on-error` or are excluded entirely depending on Deliverable 4's findings.
- The existing audit gate runs as a separate job; doesn't merge with the spec runs.

### Deliverable 7 — Close handoff

`docs/initiative-cross-platform-ui/handoff/phase-10-c-0-close.md`:

- Spec inventory + move count (before/after).
- Per-platform compile matrix status (macOS / iOS / Android: works / broken / deferred + why).
- New Family 5 rule status (lint passes on reorganized tree).
- CI workflow changes.
- Anything blocking 10B.0/10A.0 dispatch (if any).
- Codex content review verdict.

## 5. Workflow

1. `git checkout -b phase-10-c-0 phase-10`.
2. Run Deliverable 1 — spec inventory + classification. Commit.
3. Apply Deliverable 2 — moves. `crystal spec spec/web/` after; verify pass count matches pre-move. Commit.
4. Deliverable 3 — Makefile / scripts. Commit.
5. Deliverable 4 — compile matrix discovery (write doc; actually run the commands; report what works). Commit.
6. Deliverable 5 — LSP rule file. Commit.
7. Deliverable 6 — CI workflow update. Commit.
8. Deliverable 7 — close handoff. Commit.
9. Standard footer.

## 6. Acceptance gate

- ✅ Every existing spec file accounted for in the inventory + moved to correct platform dir.
- ✅ `make test-web` passes (same test count as before reorg).
- ✅ `make test-macos` passes OR has documented breakage path.
- ✅ Native compile matrix doc lists ACTUAL command output, not assumed state.
- ✅ Family 5 directory-convention rule file exists + compiles + would flag a violation if introduced.
- ✅ CI workflow updated to attempt all platform spec runs.
- ✅ Codex content review APPROVE.

## 7. Out of scope

- Fixing broken iOS/Android compile (report only; repair is future phase work).
- Family 5 deep rules (10A.final after widgets).
- LSP loader integration (10A.0 owns CustomRule wiring; this slice just ships the rule file).
- Catalog edits.
- Widget implementation.
- Owner involvement.

## 8. What success looks like

After 10C.0 closes, widget implementers in 10B.1a+ know exactly where to put new specs (`spec/native_macos/` for AppKit-specific tests, etc.), how to run them per-platform (`make test-macos`), and what platforms compile (per `native-compile-matrix.md`). Family 5's first rule keeps the convention enforceable. CI runs all feasible targets so cross-platform regressions surface automatically.

— Architect (Claude Opus 4.7), 10C.0 brief v1
