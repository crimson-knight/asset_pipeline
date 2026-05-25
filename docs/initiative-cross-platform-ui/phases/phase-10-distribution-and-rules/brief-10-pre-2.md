# Phase 10-pre.2 — Implementer Brief (DRAFT v1)

**Phase:** 10-pre.2 — API freeze + rename protocol.
**Branch:** `phase-10-pre-2` cut from `phase-10-pre-1` after that closes.
**Status:** DRAFT v1 — pending Codex antagonist + reconciliation.
**Predecessor:** 10-pre.1 closes the catalog's `coverage_today` accuracy. 10-pre.2 closes its `crystal_api_shape` accuracy.

---

## 1. What you are doing

Phase 10-pre.1 corrected the catalog's `coverage_today` fields (what's shipped vs missing). Phase 10-pre.2 corrects the catalog's `crystal_api_shape` fields (what the Crystal API actually looks like). These are the two halves of "make the catalog honest."

**Protocol:** **Code wins by default.** When the catalog's `crystal_api_shape` disagrees with the actual Crystal source, the catalog gets rewritten to match the code. Catalog preserves Apple intent identifiers (snake_case-of-Apple-name); `crystal_api_shape` documents the Crystal-idiomatic name. The catalog NEVER invents methods/operators that don't exist in code.

**Catalog wins** is rare — only when the Crystal API name is actively misleading or blocks Apple-vocabulary intent mapping. Expected: 0–3 catalog-wins cases out of 40 Class D rows. When catalog wins, the Crystal API + every consumer (Voyager, samples) renames in the same commit.

You ARE renaming Crystal source code only when explicit catalog-wins decisions require it. You are NOT writing widget implementations, LSP rules, or new intents.

## 2. Read first

Working directory: `/Users/crimsonknight/open_source_coding_projects/asset_pipeline`.

1. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/scoping-10.md` v3 — read §"10-pre.2" for scope boundary.
2. `docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-pre-1.md` v2 — predecessor brief.
3. `docs/initiative-cross-platform-ui/handoff/phase-10-pre-1-close.md` — what 10-pre.1 shipped.
4. `docs/initiative-cross-platform-ui/architecture/intent-catalog.md` — your target document, 92 entries.
5. `docs/initiative-cross-platform-ui/handoff/phase-10-pre-catalog-freshness-2026-05-25.md` — original audit's Class D spot-check section lists 9 known divergences.
6. `CLAUDE.md` — project conventions, especially Class D ("native modifier intents — direct Crystal-to-modifier translation").

For each Class D row you touch, you'll need to read source:

- `src/ui/views/*.cr` — view class definitions, init signatures, properties.
- `src/ui/*.cr` — top-level type definitions (enums like `PickerStyle`, helpers like `UI::FormState`).

## 3. Constraints (Hard Rules)

- **Forward commits only** on branch `phase-10-pre-2`. Cut the branch: `git checkout -b phase-10-pre-2 phase-10-pre-1`.
- **Code edits ONLY for catalog-wins renames** (decisions documented per-row). All other Class D rows get `crystal_api_shape` rewritten to match existing code.
- **Per-row decision log mandatory.** Every Class D row gets one entry: confirmed-correct / code-wins-rewrite / catalog-wins-rename. With rationale.
- **No new intents.** 92 catalog entries (67 top-level + 25 nested) stay.
- **No new backlog items.** Backlog is frozen after 10-pre.1.
- **Audit-scope discipline** carries forward — verify every Crystal API reference exists in source.
- Per `[[codex-as-architect-antagonist]]`: Codex content review on the corrected `crystal_api_shape` values before close.
- Per `[[complete-phase-arc-before-review]]`: no owner involvement.
- Per `[[plan-what-to-understand-not-just-what-to-build]]`: if a row's Crystal API shape needs a design decision (e.g., should `UI::Sheet.present` take an argument?), do NOT improvise — surface to architect for ruling.

## 4. Deliverables

### Deliverable 1 — Class D rename audit + decision log

Write `docs/initiative-cross-platform-ui/handoff/phase-10-pre-2-rename-decisions.md`:

For every Class D row in the catalog (~40 entries; the catalog has 92 entries total but most non-Class-D rows don't have `crystal_api_shape`), record:

```
### `:intent_identifier`

- **Catalog crystal_api_shape:** `<current value>`
- **Actual Crystal API:** `<grep results from src/>`  (cite file:line)
- **Decision:** confirmed-correct / code-wins-rewrite / catalog-wins-rename
- **Rationale:** [1 sentence]
- **If catalog-wins-rename:** [what code changes, what consumers update]
```

The 8 rows the 10-pre.1 implementer marked with `# pending 10-pre.2 rename audit` are your priority. Plus any other Class D rows whose `crystal_api_shape` you haven't verified.

Known divergences (from freshness audit):
- `:list` — catalog says `UI::List` with `<<`; actual is `UI::ListView` with `sections:` or `flat(items:)`.
- `:list_row_separator` — catalog says per-row; actual `shows_separators : Bool` is list-level.
- `:sheet` — catalog says `sheet.present(from: parent)`; actual `SheetPresenter#present` takes no args.
- `:presentation_detents` — catalog name wrong; actual is `detents`.
- `:presentation_drag_indicator` — catalog says three-valued symbol; actual is `Bool shows_drag_indicator`.
- `:toolbar` — catalog init signature wrong; actual `UI::Toolbar.new(@title : String?)`.
- `:toolbar_item` — catalog uses `<<` + `on_tap`; actual `add_item(...)` + `action`.
- `:menu_picker_style` — catalog says `:menu` symbol; actual `style : PickerStyle = PickerStyle::Menu`.
- `:context_menu` — catalog setter signature fictional.
- `:menu` — catalog claims `UI::Menu` class; actual is `UI::MenuButton`.

For each: code wins (expected default). For each rename, document why catalog was wrong AND what the corrected `crystal_api_shape` text becomes.

### Deliverable 2 — Catalog `crystal_api_shape` corrections

For each Class D row in `intent-catalog.md`:

- If decision was code-wins-rewrite → rewrite `crystal_api_shape` to match Crystal source. Format: `crystal_api_shape: \`<actual Crystal example>\``. Example: change `list = UI::List.new; list << row` to `list = UI::ListView.flat(items: rows)`.
- If decision was catalog-wins-rename → rewrite the Crystal source first (Deliverable 3), then update the catalog `crystal_api_shape` to match the new code.
- If decision was confirmed-correct → no change, but remove any `# pending 10-pre.2 rename audit` marker.

After: every Class D row's `crystal_api_shape` is verifiable by grep + visit-to-line.

### Deliverable 3 — Catalog-wins renames (expected 0–3)

For any row where the team decided catalog-wins:

- Edit the Crystal source file to rename the class / method / property.
- Update every consumer: Voyager (`samples/initiative-cross-platform-ui-voyager/`), any other samples, any spec files.
- Verify compilation: `crystal build src/ui/views/<renamed>.cr` (or full build if cross-cutting).
- The rename + all consumer updates go in ONE atomic commit.
- Add a migration note in `docs/initiative-cross-platform-ui/handoff/phase-10-pre-2-renames.md` (only if any renames happened).

### Deliverable 4 — intent-backlog.md final count freeze

After 10-pre.1, backlog had 36 active items. 10-pre.2 should NOT add new items. Confirm:

- Count entries in `intent-backlog.md`.
- Verify count matches the "Frozen 2026-05-25" note at the top.
- If count drifted, restore to the frozen number (the 10-pre.2 work shouldn't add backlog).

### Deliverable 5 — Close handoff

Write `docs/initiative-cross-platform-ui/handoff/phase-10-pre-2-close.md`:

- Headline: # of Class D rows verified (confirmed + corrected).
- Decision distribution: X confirmed-correct, Y code-wins-rewrite, Z catalog-wins-rename.
- Renames shipped (if any): list with commit SHAs.
- Lint output: `crystal run scripts/lint_intent_catalog.cr` exits 0.
- Cross-document consistency check: catalog vs widget-intent-mapping.md vs translation-matrix.md.
- Codex content review verdict.
- Anything surfaced beyond scope.

## 5. Workflow

1. `git checkout -b phase-10-pre-2 phase-10-pre-1`.
2. Identify all Class D rows in the catalog. For each, read source + check for divergence.
3. Build the per-row decision log (Deliverable 1).
4. Apply Deliverable 2 (catalog rewrites) — incremental commits per ~10 rows.
5. If any catalog-wins renames: apply Deliverable 3 in one atomic commit (Crystal + consumers + catalog text).
6. Run `crystal run scripts/lint_intent_catalog.cr` — exit 0.
7. Verify count freeze (Deliverable 4).
8. Write close handoff (Deliverable 5).
9. Architect dispatches Codex content review on the corrected catalog.
10. Standard commit footer.

## 6. Acceptance gate

- ✅ Every Class D row's `crystal_api_shape` is either confirmed correct against source OR rewritten with verification.
- ✅ Per-row decision log shipped (Deliverable 1).
- ✅ `# pending 10-pre.2 rename audit` markers all removed.
- ✅ `crystal run scripts/lint_intent_catalog.cr` exits 0.
- ✅ If any catalog-wins renames: `crystal build` of affected files passes; Voyager compiles.
- ✅ Codex content review APPROVE.

## 7. Out of scope

- Widget implementation (10B).
- New intents.
- New backlog items.
- `coverage_today` corrections (10-pre.1 already done).
- LSP rules (10A).
- Spec reorganization (10C.0).
- Owner involvement.

## 8. What success looks like

After 10-pre.2 closes, the catalog's `crystal_api_shape` field is an accurate quick-reference for "how do I use this in Crystal today." A consumer (human or AI agent) reading a catalog row can copy-paste the `crystal_api_shape` example and have it compile (modulo their state variables). The catalog becomes a TRUE source of truth for both intent vocabulary (Apple) and Crystal API surface (asset_pipeline) — completing the truthfulness work 10-pre started.

— Architect (Claude Opus 4.7), 10-pre.2 brief v1
