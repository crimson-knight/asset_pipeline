# Translation Matrix

**Companion to:** `intent-catalog.md`, `intent-routing-candidates.md`, `tier-2-translation-contract.md`.

For each Class A intent, the per-platform default translation: which existing `UI::View` class implements the default, or `MISSING` (backlog entry).

This matrix is small because Class A has 1 entry. As more Class A intents are identified in future phases (`:reorder_list_items` is a candidate per the co-plan), the matrix grows.

---

## Class A intent: `:swipe_actions`

| Platform | Default widget | Status | Notes |
|---|---|---|---|
| iOS | `UI::SwipeActionRow` | ✅ shipped | `src/ui/views/swipe_action_row.cr`; UIKit renderer emits swipe gesture. |
| iPadOS | `UI::SwipeActionRow` | ✅ shipped | Same as iOS. |
| macOS | `UI::InlineActionRow` | ❌ missing | Currently `UI::SwipeActionRow` is used but AppKit renderer emits inline buttons anyway (`appkit_renderer.cr:3801`). The named widget should match the visual representation. **Backlog item B-001.** |
| Android | `UI::SwipeActionRow` (stub) | ⚠️ partial | Android renderer is explicitly a stub at `android_renderer.cr:3148` — renders only the content view, defers proper `SwipeToDismissBox` integration to a future phase. **Backlog item B-035.** |
| web_wide | `UI::InlineActionRow` | ❌ missing | Desktop web has no native swipe gesture. Inline trailing buttons (with hover affordance) are idiomatic. **Backlog item B-002.** |
| web_narrow | `UI::SwipeActionRow` | ✅ shipped (web renderer) | Mobile web JS-driven swipe-reveal. |

**3/6 default translations shipped; 1/6 partial (Android stub); 2/6 missing.** See `intent-backlog.md` for B-001, B-002, B-035.

---

## Freshness reconciliation (IMPLEMENTER fills this section)

Per brief-9 §5 Item 3 — this paragraph is **implementer's work**, not architect's. The implementer:

1. Runs `ls src/ui/views/*.cr | wc -l` to get the actual count.
2. Identifies what categories of files exist in `src/ui/views/`:
   - Top-level concrete widgets (`button.cr`, `text_field.cr`, etc.).
   - Gate-stub siblings (`src/ui/views/_gate_stubs/*.cr` per CLAUDE.md:158-160).
   - `*_with_web_fallback.cr` companion classes for Tier 3 widgets.
   - Presenters / compat layer files (if any).
3. Reconciles the 59-vs-80 discrepancy between the `component-mapping-matrix` skill and what's actually under `src/ui/views/`.
4. Writes a one-paragraph reconciliation explaining the final canonical count and what each category contributes.

**Placeholder for implementer output:**

> *[Implementer: replace this placeholder with the freshness reconciliation paragraph after running the count + categorizing the files.]*

The reconciliation gets cross-referenced from `widget-intent-mapping.md` (Item 6) so the audit table's row count matches reality.

---

## Future Class A candidates (not yet promoted)

These are mentioned in the co-plan but did not meet the Class A bar in Phase 9:

- `:reorder_list_items` (`onMove`) — currently Class D. If drag-handle (iOS) vs up-down-buttons (web-wide) proves to be different widgets rather than the same widget with platform-different rendering, this gets promoted to Class A.
- `:navigation_split_view` — currently Class D. If `NavigationStack` on compact vs `NavigationSplitView` on regular size-class proves to require different widget classes (not just different renderer behavior), it could become Class A. The current `UI::NavigationStack` + `UI::NavigationSplitView` setup treats them as separate widgets the author picks; that may already be correct.

Future phases evaluate these candidates against the materially-different-widget bar. The default expectation is "stay Class D unless proven otherwise."

— Architect (Claude Opus 4.7)
