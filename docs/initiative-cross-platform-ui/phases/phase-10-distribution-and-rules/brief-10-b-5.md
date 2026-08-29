# Phase 10B.5 — Remaining Class D implementations

**Branch:** `phase-10-b-5` from `phase-10` (will be cut after 10B.4 lands).
**Status:** v1. Audit-first sub-phase.

## Context

Class D intents per the four-class taxonomy are "native modifier 1:1 translation" — modifier-style chainable methods that should map directly to SwiftUI / UIKit / AppKit / Android primitives without abstraction. 10B.4 closed the missing-WIDGET gap (FullScreenCover, Inspector, ToolbarItemGroup, ToolbarSpacer). 10B.5 closes any remaining Class D MODIFIER gap.

## Audit task (do this FIRST before implementing)

1. Read `docs/initiative-cross-platform-ui/architecture/intent-routing-candidates.md`.
2. Filter for Class D entries (look for `class: D` or "native modifier 1:1 translation" or equivalent classification).
3. For each Class D entry, check:
   - Is it shipped already? (search `src/ui/view.cr` properties + `src/ui/views/`.)
   - Is the per-platform renderer mapping in place?
   - Does it have a spec?
4. Compile the gap list.

## Possible outcomes

- **No gap**: write a close handoff documenting the audit findings + close 10B.5 as no-op. This is fine.
- **Small gap (1-3 modifiers)**: ship them as properties on `UI::View` (or value-type structs if appropriate). Update renderers. Add specs.
- **Larger gap**: dispatch sub-slices if needed, OR ship in a single 10B.5 close. Use judgment.

## If there ARE Class D modifiers to ship

Per-modifier deliverables:

1. **Property on `UI::View`** (or value-type) — name + type matching SwiftUI / cross-platform convention.
2. **Renderer threading** — all 4 renderers apply the modifier in their visit pipeline.
3. **Default value** — what does "no modifier set" mean? Pick conservative defaults.
4. **Spec** — `spec/web/ui/<modifier>_spec.cr` or extended `accessibility_metadata_spec.cr`-style.

## Acceptance

- ✅ Audit doc shipped at `docs/initiative-cross-platform-ui/handoff/phase-10-b-5-audit.md` listing every Class D entry + shipped/missing status.
- ✅ Missing modifiers (if any) shipped per the deliverables above.
- ✅ Specs pass.
- ✅ Lint + build green.
- ✅ Codex content review APPROVE (even on a no-op close — Codex confirms the audit is honest).

## Out of scope

- New widgets (10B.4 owned that).
- Class C features (10B.3.x owned that).
- Public docs (10A.final).
- HIG validation.

— Architect (Claude Opus 4.7), 10B.5 brief v1
