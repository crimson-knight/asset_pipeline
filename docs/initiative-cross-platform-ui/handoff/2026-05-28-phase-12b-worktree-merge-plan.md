# Phase 12.B — phase-10-d-polish worktree merge plan

**Status:** Investigation report. The owner decides the merge approach; the architect proposes.

## Why the merge matters

V1 and V2 (per `presentation-lifecycle-contract.md`) manifested against the `phase-10-d-polish` worktree, not against current main (`phase-10-d-refocus`). The V1+V2 reproduction specs at `spec/native_ios/ui_interaction/{confirmation_dialog,voyager_toolbar}_spec.cr` are pre-staged but cannot run until the polish worktree's todos extensions land in main.

This document is the merge-plan deliverable for Phase 12.B's "polish-worktree merge" sub-step.

## What's in the polish worktree

`git log --oneline phase-10-d-refocus..phase-10-d-polish` returns 25+ commits across:

### Structural changes
- **`UI::Intent` rename → `UI::WidgetRoute` / `UI::SystemAction`.** Touches `src/ui/intent.cr` (deleted), new `src/ui/widget_route.cr`, renamed `src/ui/intent/` → `src/ui/widget_route/`. Owner-approved in the original session.
- **Module reorganization** for the intent→widget_route split.

### Voyager extensions (V1+V2 target code)
- **`b969e499` — B1+B2+B3+B4+B5: Todos screen wires Alert/ActionSheet/Sheet/DatePicker/Popover.** This is the commit where V1's target action sheet on row tap lands. Also adds the editor sheet, the share action sheet, and the overflow popover. V2's header sort filters land in a different commit.
- **`3b832963` — Voyager state + controller pending-modal flags.** State machinery for the new modals.
- **`a678806e` — A1-A4: ListViewFacade Mail-style chrome defaults.**

### Iter 2 fixes (from owner hand-test)
- B-ACTIONSHEET-MULTI-ACTION (ForEach actions)
- B-SHEET-INTERACTIVE-DISMISS-DISABLED
- B-DATEPICKER-STYLE-PROPERTY (compact/graphical/wheels)
- B-LIST-SWIPE-TINT + B-LIST-SWIPE-LABEL-STYLE
- B-POPOVER-ANCHOR-VIEW (anchor by test_id)

### Bug fixes
- ActionSheet SIGSEGV (token setters use boxed UInt64)
- DatePicker seed crash (Time.utc not Time.local)
- DatePicker year offset 3995→2026 fix
- Popover compact-adaptation force-popover-chrome on iPhone

### Docs + evidence
- Per-widget usage docs (6 widgets)
- Hand-test guides
- 5 screenshot scenarios
- Updated intent-catalog + intent-backlog (rename consistency)

## What's in current main (refocus) that polish doesn't have

- All Phase 12.A scaffold (gate v2, contracts, manifest, validator, harness, marker emitter, smoke spec)
- `BoolStorage.markerWidget` + `viewID` properties (in `ValueStorage.swift`)
- Sheet write-side markers + host-teardown probe (just shipped, Phase 12.B step 2)
- Voyager launch + heartbeat markers in `VoyagerApp.swift`

The merge is a TWO-SIDED diff — both branches have substantive work the other doesn't.

## Diff size

`git diff --stat` returns:
```
132 files changed, 4342 insertions(+), 6115 deletions(-)
```

Most of the deletions are the rename (`Intent` → `WidgetRoute`). Net new content is ~1,800 lines.

## Conflict surface

Files modified by BOTH branches (will conflict):
- `swift/.../Facades/ConfirmationDialogFacade.swift`
- `swift/.../Facades/PopoverFacade.swift`
- `swift/.../Facades/SheetFacade.swift`
- `swift/.../Facades/AlertFacade.swift`
- `swift/.../Facades/ValueStorage.swift`
- `swift/.../InteractionContracts.swift` — only exists in refocus; polish doesn't have it (will not conflict, just add)

Files only modified in polish (additive, no conflict):
- `src/ui/widget_route.cr` (new file)
- `src/ui/intent/` → `src/ui/widget_route/` (rename)
- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` (extensive)
- `samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr` (extensive)
- Iter 2 fix commits
- Per-widget usage docs
- Screenshots + scenarios

Files only modified in refocus (no conflict from polish side):
- All `docs/initiative-cross-platform-ui/` infrastructure
- `scripts/validate_catalog_coverage.cr`, `scripts/capture_tap_coordinates.sh`
- `spec/native_ios/ui_interaction/` (all new)
- `src/ui/native/{interaction_contracts,swiftkit_bridge}.{cr,m}` (markers only)
- `samples/.../ios/Sources/VoyagerApp.swift` (heartbeat)

## Strategic options

### Option A — Merge polish INTO refocus (refocus is the receiving branch)

```bash
git checkout phase-10-d-refocus
git merge phase-10-d-polish
# Resolve conflicts in the 4-5 facade files
```

**Pros:**
- Refocus's Phase 12.A infrastructure stays intact in commit history.
- Polish's commit granularity is preserved.
- Natural fast-forward landing point for the eventual merge to `feature/utility-first-css-asset-pipeline`.

**Cons:**
- ~5 facade files need manual conflict resolution. The conflicts are not trivial — both sides made structural changes (refocus added markerWidget; polish added new methods + property handling).
- Polish's intent → widget_route rename means refocus's pending V1+V2 specs reference `:swipe_actions` intent IDs that may need to update.

### Option B — Rebase polish ONTO refocus

```bash
git checkout phase-10-d-polish
git rebase phase-10-d-refocus
git checkout phase-10-d-refocus
git merge --ff-only phase-10-d-polish
```

**Pros:**
- Linear history.
- Same final state as A but cleaner log.

**Cons:**
- 25+ rebased commits = 25+ potential conflict resolutions.
- High risk of subtle regressions during rebase.

### Option C — Squash-merge polish

```bash
git checkout phase-10-d-refocus
git merge --squash phase-10-d-polish
git commit -m "[Phase 12.B] Merge phase-10-d-polish (squashed) — Voyager modal extensions + iter-2 fixes"
```

**Pros:**
- Single commit; clean log.
- Conflicts resolved once, not per-commit.

**Cons:**
- Loses polish's commit-level history (iter 2 fix attribution).
- The handoff docs in polish reference specific commit SHAs that won't exist after squash.

### Option D — Cherry-pick selectively

Pick only the commits that wire Voyager's V1+V2 target code (B1-B5 + iter 2 fixes), skip the larger refactor.

**Pros:**
- Minimal blast radius.
- Defers the intent → widget_route rename.

**Cons:**
- Polish's iter 2 fixes assume the rename has happened. Cherry-picking selectively means re-doing the rename, which is more work than a full merge.
- The cherry-pick subset doesn't actually shrink the blast radius — the V1+V2 target code is intertwined with the rename + facade changes.

## Architect recommendation: Option A

Reasoning:
1. The conflict surface is bounded (5 facade files). Each conflict is mechanically resolvable by keeping refocus's marker-tagging additions AND polish's new methods.
2. Polish's commit history is informative (B1-B5 + iter-2 fix attribution).
3. The Intent → WidgetRoute rename is owner-approved; integrating it now means refocus's pending specs can update to use the new names in the same merge commit.

Suggested conflict resolution policy:
- **ValueStorage.swift:** Keep refocus's `markerWidget` + `viewID` properties. Polish doesn't touch BoolStorage in a way that conflicts; the deletion shown in `git diff --stat` is the rename-driven move (BoolStorage didn't change semantically).
- **ConfirmationDialogFacade.swift / PopoverFacade.swift / AlertFacade.swift:** Keep BOTH refocus's marker tagging AND polish's new functionality (multi-action ForEach, anchored popover, interactive-dismiss-disabled). Merge sequentially in the same scope block.
- **SheetFacade.swift:** Keep refocus's host-teardown probe (just shipped in commit `449336c0`) AND polish's interactive-dismiss-disabled + detents + materials changes. Both apply to different parts of the .sheet modifier chain.

## What this leaves for the owner

The owner decides:
1. **Approve Option A** (or pick B/C/D)
2. **Approve the conflict resolution policy** above (or specify a different one)
3. **Approve who does the merge** — architect autonomously, or owner-driven with architect coaching

The merge is reversible up to the next push. Tagging refocus's current HEAD (`449336c0`) as `pre-polish-merge` before starting gives a clean rollback point.

— Architect (Claude Opus 4.7), Phase 12.B worktree merge plan, 2026-05-28
