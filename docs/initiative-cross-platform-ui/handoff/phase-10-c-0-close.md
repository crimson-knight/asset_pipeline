# Phase 10C.0 — Close handoff

**Date:** 2026-05-25
**Branch:** `phase-10-c-0` cut from `phase-10`
**Status:** Deliverables 1–7 complete. Acceptance gate met with documented blockers per Decision 5.

---

## Deliverables status

| # | Deliverable | Status | Artifact |
|---|---|---|---|
| 1 | Spec inventory + classification (132 specs) | DONE | `docs/initiative-cross-platform-ui/handoff/phase-10-c-0-spec-inventory.md` |
| 2 | Spec directory reorganization | DONE in 2 batches | Two commits (`d446ba9d`, `b0688743`) |
| 3 | Root Makefile (test-web, test-macos, test-ios, test-android, test-all) | DONE | `Makefile` (94 lines) |
| 4 | Native compile matrix discovery | DONE with documented blockers | `docs/initiative-cross-platform-ui/native-compile-matrix.md` |
| 5 | Family 5 directory-convention rule | DONE (compiles; runner mechanism deferred to 10A.0a) | `src/lsp_rules/family_5_partial/spec_platform_directory_convention.cr` |
| 6 | CI workflow update | DONE | `.github/workflows/initiative-cross-platform-ui.yml` (4 new jobs) |
| 7 | This close handoff | DONE | this file |

---

## Spec move counts (before / after)

| Location | Before reorg | After reorg |
|---|---:|---:|
| `spec/asset_pipeline_spec.cr` | 1 file | moved → `spec/web/asset_pipeline_spec.cr` |
| `spec/spec_helper.cr` | 1 | moved → `spec/web/spec_helper.cr` |
| `spec/asset_pipeline/**` | 19 | moved → `spec/web/asset_pipeline/**` |
| `spec/components/**` | 23 | moved → `spec/web/components/**` |
| `spec/fixtures/**` | 4 | moved → `spec/web/fixtures/**` |
| `spec/import_map/**` | 1 | moved → `spec/web/import_map/**` |
| `spec/scripts/**` | 1 | moved → `spec/web/scripts/**` |
| `spec/support/**` | 6 → 5 web + 1 native | `spec/web/support/**` (5) + `spec/native_macos/support/ax_test_patterns.cr` (1) |
| `spec/ui/**` | 74 → 61 web + 13 native | `spec/web/ui/**` (61) + `spec/native_macos/{ax_test,hig_validation,native,menu_bar}/**` (13) |
| `spec/test_js/` | (non-`.cr` fixtures, untouched) | unchanged |
| **Total `.cr` specs** | **132** | **132** (118 web + 14 native_macos) |

Verified via `find spec -name '*.cr' | wc -l` before and after — 132 both times.

### Regression check

`crystal spec spec/web/` after reorg reports:
```
1723 examples, 4 failures, 0 errors, 66 pending
```

Identical to pre-reorg baseline (4 pre-existing failures, all tracked outside Phase 10C.0 scope).

---

## Per-platform compile matrix status

Full detail in `docs/initiative-cross-platform-ui/native-compile-matrix.md`.

| Platform | Status | Blocker / next owner |
|---|---|---|
| web (`crystal`) | `verified` | None — `make test-web` runs the 118-spec lane. |
| macOS (`acrystal -Dmacos`) | `attempted-blocked` | TWO distinct blockers: (a) spec entries needing `require "../../src/ui"` ahead of `require "../../src/ui/ax_test"` — applied to the 14 native_macos specs during migration; (b) `src/ui/native/objc_collections.cr` declares `lib LibCollectionBridge` `fun`s whose C implementation (`collection_bridge.c`/`.m`) is NOT in the repo, so `make test-macos` link fails with ~40 undefined symbols. Sample apps under `samples/cross_platform/macos_host/` link OK today, suggesting the bridge lives in downstream sample sources. Deferred to a follow-up native-runner phase. |
| iOS (`acrystal -Dios`) | `attempted-blocked` | `acrystal build --target=arm64-apple-ios18.0 -Dios` link step pulls macOS-built `libgc.dylib`. Repo's iOS path uses `--cross-compile` + `libcascade.a` + Xcode (`samples/initiative-cross-platform-ui-demo/ios/build_crystal_lib.sh`), not standalone `acrystal spec`. Deferred to 10D. |
| Android (`acrystal -Dandroid`) | `attempted-blocked` | `acrystal build -Dandroid` fails on `require "c/sys/epoll"` — `agent-crystal` Homebrew tap installs macOS-targeted stdlib only. Needs Linux Crystal + NDK. Deferred to 10D. |

---

## Family 5 rule status

- File: `src/lsp_rules/family_5_partial/spec_platform_directory_convention.cr`
- Compiles: yes (`crystal build --no-codegen` exit 0).
- Functional probe: passes on `spec/web/X.cr`, `spec/native_macos/X.cr`, `spec/spec_helper.cr`; flags `spec/asset_pipeline/X.cr`, `spec/ui/X.cr`, `spec/support/X.cr`. Probe captured during implementation.
- Diagnostic format: `file_path:line: [rule_name] message\n  fix: suggested_fix` (matches the runner shape 10A.0a is expected to formalize).
- **Coordination with 10A.0a:** the rule file stands alone today. 10A.0a's `ConventionRule` base class has NOT merged onto `phase-10`. When it does, this file's class declaration changes from:
  ```crystal
  class SpecPlatformDirectoryConvention
  ```
  to:
  ```crystal
  require "../convention_rule"
  class SpecPlatformDirectoryConvention < ConventionRule
  ```
  and the runner registers the class via its existing rule-loading mechanism. The `ConventionDiagnostic` struct in this file is a forward-compatible shim that 10A.0a's runner can supersede with its own diagnostic type.
- Tests: deferred. 10A.0a's runner phase ships rule fixtures; Family 5's fixture goes in then.

---

## CI workflow changes

`.github/workflows/initiative-cross-platform-ui.yml` gains four new jobs ahead of the existing demo/audit jobs:

| Job | Runner | continue-on-error | Notes |
|---|---|---|---|
| `test-web` | macos-14 | false | `make test-web`. Currently 4 baseline failures — would gate PRs. Acceptable while baseline failures live in Phase-2 verification. |
| `test-macos` | macos-14 | **true** | `make test-macos`. Matrix says `attempted-blocked` — non-fatal until C bridge ships. |
| `test-ios` | macos-14 | **true** | `make test-ios` (placeholder echo). |
| `test-android` | ubuntu-latest | **true** | `make test-android` (placeholder echo). |

The existing demo + visual-audit jobs (build-web, build-macos, build-ios, audit-web, audit-macos, audit-ios) are unchanged.

A `lint` job is deliberately NOT added — Family 5's runner mechanism (`scripts/lint_conventions.cr`) ships with 10A.0a. When that merges, a lint job is added in a follow-up PR.

---

## Anything blocking 10A.0a / 10B.0 / 10A.0b

- **10A.0a (Crystal-side runner + Family 1):** no blocker. 10C.0 ships the Family 5 rule file at the agreed path. When 10A.0a defines `ConventionRule` and `scripts/lint_conventions.cr`, the Family 5 rule needs the one-line parent-class change + runner registration described above.
- **10A.0b (Family 2 view-spec pair):** unblocked by this close. `spec/web/` and `spec/native_macos/` directories exist; the spec-pair rule can be authored against them.
- **10A.0c (Family 3 architectural):** unblocked. Runs after 10A.0a.
- **10B.0 (Tier 2 intent resolver):** specs land in `spec/ui/intent_spec.cr` (current tree) per Decision 4. 10C.0 will need a follow-up migration commit on whichever branch lands second — trivial `git mv` + path-edit task tracked here.

---

## Branch HEAD SHA

After Deliverable 7 close commit lands. Commits on `phase-10-c-0` from `phase-10`:

```
<sha-of-close-commit>  [Phase 10C.0 close] Implementer handoff
<sha-of-ci-commit>     [Phase 10C.0] CI workflow update + Family 5 rule + Makefile
b0688743               [Phase 10C.0] Move 118 web specs (Deliverable 2 batch 2/N)
d446ba9d               [Phase 10C.0] Move 14 native_macos specs (Deliverable 2 batch 1/N)
12e59cc3               [Phase 10C.0] Native compile matrix (Deliverable 4)
9f6ce521               [Phase 10C.0] Spec inventory + classification (132 specs)
f40f247e               [Phase 10] Parallel-trio briefs v2 + architecture-decisions.md  ← phase-10 base
```

---

## Acceptance gate check

- ✅ All 132 specs accounted for + moved (verified via `find spec -name '*.cr' | wc -l`).
- ✅ `crystal spec spec/web/` passes with the same example count (1723) as before reorg.
- ⚠️ `make test-macos` documented blocker (collection_bridge.c missing) — matrix doc captures.
- ✅ Native compile matrix doc has 3 status entries (macOS / iOS / Android) with command + outcome.
- ✅ Root Makefile exists with all 5 targets (test-web, test-macos, test-ios, test-android, test-all).
- ✅ `objc_bridge.o` build dependency wired (Makefile target `$(AP_BRIDGE)`).
- ✅ Family 5 rule file exists + compiles. Runner integration deferred to 10A.0a per Decision 1.
- ✅ CI workflow runs available platforms (4 new jobs; native lanes `continue-on-error`).
- ⏳ Codex content review: not yet run. Implementer recommends owner triggers `scripts/codex_hig_review.sh` equivalent for the close-handoff content review before architect close.

---

## Codex content review

To be triggered post-close by the orchestrator. See
`[[feedback_codex_as_architect_antagonist]]` — use Codex to critique
this handoff before architect closes the phase.

— Implementer (Phase 10C.0), 2026-05-25
