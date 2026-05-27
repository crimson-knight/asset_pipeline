# Phase 10D-final — Preflight report (Deliverable 0)

**Branch:** `phase-10-d-final` cut from `phase-10-d-refocus` HEAD `69290bcf` (the brief v2 commit).
**Worktree:** `/Users/crimsonknight/open_source_coding_projects/asset_pipeline/.claude/worktrees/phase-10-d-final`.
**Author:** Implementer (Claude Opus 4.7), 10D-final iter-1.

This is the structural fix Codex finding #14 demanded: the implementer reads the codebase BEFORE writing diffs so the brief's assumptions get validated against real source.

---

## 1. Final rename names

The brief's proposal — `UI::WidgetRoute` (resolve) + `UI::SystemAction` (perform) — is collision-free.

Grep results (both empty):
```
rg -l 'WidgetRoute' src samples spec scripts → (no matches)
rg -l 'SystemAction' src samples spec scripts → (no matches)
```

Existing `UI::Widget` (`src/ui/widgets.cr:116`) is a sibling namespace under `UI`, not a parent — `UI::WidgetRoute` is unambiguous. `UI::Widgets` (the plural collection at `src/ui/widgets.cr:317`) and `UI::WidgetPlacement` likewise do not conflict.

**Decision: proceed with the brief's names verbatim. No alternative proposals needed.**

`declares_capabilities` macro keeps its name (the brief already noted this). The macro is the widget-side declaration of "what swipe edges / roles do I cover?"; capabilities are still what widgets declare, regardless of whether the routing namespace is called Intent or WidgetRoute.

---

## 2. `rg UI::Intent` audit

Run scoped to `src samples spec scripts docs/initiative-cross-platform-ui`:

- **Total files touched: 72**
- **Total occurrences: 736**

### Files by category

**Library source (will rename names + content):** 14 files
- `src/ui.cr` (3)
- `src/ui/environment.cr` (3)
- `src/ui/view.cr` (6)
- `src/ui/intent.cr` (19) → `src/ui/widget_route.cr` (split, see below)
- `src/ui/intent_bootstrap.cr` (12) → `src/ui/widget_route/bootstrap.cr` + `src/ui/system_action/bootstrap.cr`
- `src/ui/intent/registry.cr` (6) → `src/ui/widget_route/registry.cr`
- `src/ui/intent/dispatch_result.cr` (3) → `src/ui/system_action/result.cr`
- `src/ui/intent/platform_feature_binding.cr` (4) → `src/ui/system_action/platform_binding.cr`
- `src/ui/intent/class_c_bootstrap.cr` (121) → folded into `src/ui/system_action/bootstrap.cr` (rename + relocation)
- `src/ui/intent/class_c_registry.cr` (registry, count unlisted but present) → `src/ui/system_action/registry.cr`
- `src/ui/view.cr` (declares_capabilities macro lives here — keep name, drop only references)
- `src/ui/views/swipe_action_row.cr` (capability declarations reference `:swipe_actions` intent id — drop intent term in docstrings)
- `src/asset_pipeline/amber_integration.cr` (13)
- `src/asset_pipeline/native_app.cr` (5)
- `src/asset_pipeline/native_context.cr` (count unlisted but present)
- `src/ui/native/objc_bridge.m` (count unlisted but present) — needs check

**Lint rules (rename file + class + rule name string):** 2 files
- `src/lsp_rules/family_3_architectural/intent_resolve_capability_arg_rule.cr` (11) → `widget_route_resolve_capability_arg_rule.cr`
- `src/lsp_rules/family_3_architectural/override_intent_widget_subclass_rule.cr` (27) → `override_widget_subclass_rule.cr`

**Sample app (Voyager — rename only the API calls; screen file paths stay):** 7 files
- `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr`
- `samples/initiative-cross-platform-ui-voyager/controllers/todos_controller.cr`
- `samples/initiative-cross-platform-ui-voyager/host_bootstrap.cr`
- `samples/initiative-cross-platform-ui-voyager/ios/bridge.cr`
- `samples/initiative-cross-platform-ui-voyager/macos/host.cr`
- `samples/initiative-cross-platform-ui-voyager/screens/phase_10/class_c_dispatch_screen.cr`
- `samples/initiative-cross-platform-ui-voyager/screens/phase_10/intent_resolver_screen.cr`
- `samples/initiative-cross-platform-ui-voyager/screens/phase_10/phase_10_exerciser_state.cr`

Phase 10 exerciser screens may be renamed cosmetically (`intent_resolver_screen.cr` → `widget_route_resolver_screen.cr`) or left as-is with internal renames only. **Decision: leave file names, rename only the contents** — file rename adds extra git churn without semantic value, and these screens are not on the demo path the owner exercises in 10D-final.

**Specs:** 17 files
- `spec/web/ui/intent_*.cr` × 4 (≈ 222 occurrences) → renamed
- `spec/web/ui/swipe_actions_capability_audit_spec.cr` (48) → rename refs inside, file stays
- `spec/web/ui/views/android_swipe_action_row_spec.cr` → minimal refs
- `spec/web/lint_conventions/family_3_architectural_spec.cr` → references the renamed rule classes
- `spec/web/lint_conventions/fixtures/family_3_architectural/intent_resolve_*.cr` × 4 → rename file + contents
- `spec/web/lint_conventions/fixtures/family_3_architectural/override_intent_*.cr` × 6 → rename file + contents

**Docs scoped under `docs/initiative-cross-platform-ui/`:** 31 files

Per the brief:
> Archived handoffs (`docs/initiative-cross-platform-ui/handoff/phase-10-*-close.md` etc.) MAY keep old names for historical accuracy. New docs MUST use new names.

**Decision:** archived close handoffs and historical scoping/coplan/brief docs from Phases 9, 10A, 10B, 10D-exerciser, 10D-refocus are **OUT OF SCOPE for content edits**. They are historical artifacts. The acceptance grep is scoped to exclude them explicitly:

```
rg -n 'UI::Intent|Intent::Registry|Intent::Class|::Intent\.|override_intent|intent_bootstrap|family_3_architectural/intent_' \
  src samples spec scripts \
  docs/initiative-cross-platform-ui/architecture \
  docs/initiative-cross-platform-ui/tutorial-ui-app.md \
  docs/initiative-cross-platform-ui/verification-runbook.md \
  docs/initiative-cross-platform-ui/tier-matrix.md \
  docs/initiative-cross-platform-ui/web-target-position.md \
  docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/brief-10-d-final.md \
  docs/initiative-cross-platform-ui/phases/phase-10-distribution-and-rules/architecture-decisions.md
```

Architecture and live docs MUST be updated. Historical phase docs (Phases 9, 10A, 10B, 10D-exerciser, 10D-refocus brief and scoping documents) keep old names for historical accuracy.

Files in `docs/initiative-cross-platform-ui/architecture/`:
- `intent-routing-candidates.md` → rename file to `widget-route-routing-candidates.md` + content
- `swipe-actions-capability-audit.md` → contents only
- `tier-2-translation-contract.md` → contents only (13 occurrences)

### Directory rename plan

- `src/ui/intent/` → splits into `src/ui/widget_route/` (registry + bootstrap files for widget resolution) and `src/ui/system_action/` (registry + bootstrap + result + platform_binding for OS calls).

- `src/ui/intent.cr` → `src/ui/widget_route.cr` exports `UI::WidgetRoute.resolve(...)`. The `UI::SystemAction` module gets its own `src/ui/system_action.cr` file exporting `UI::SystemAction.perform(...)`.

The split mirrors the semantic split: routes (Class A/B widget resolution) vs system actions (Class C OS dispatch).

---

## 3. `UI::ListView` UIKit + SwiftKit facade audit

### Current state (verified by reading source)

**Crystal-side (`src/ui/views/list_view.cr`):**
- Has `sections`, `style`, `layout`, `columns`, `item_spacing`, `shows_separators`.
- Has `on_item_tap : Proc(Int32, Int32, Nil)?` (section index, item index) — **declared but NOT wired through to UIKit** (the populator doesn't register or emit a token).
- Has NO `on_move`, NO `leading_swipe_actions`, NO `trailing_swipe_actions`.

**UIKit renderer (`src/ui/renderers/uikit_renderer.cr:1097`):**
- `visit(UI::ListView)` allocates `apsk_list_view_overrides_new`, calls `populate_list_view`, walks `view.sections` and renders each item's view, then calls `apsk_make_list_view(child_views, child_count, overrides)`.
- The token plumbing for `on_item_tap` is NOT emitted.

**SwiftKit facade (`swift/.../ListViewFacade.swift`):**
- Receives flat `childViews` + section counts/headers/footers, slices into Sections.
- No per-row tap handler. No `.swipeActions`. No `.onMove`.

**Overrides class (`swift/.../ListViewOverrides.swift`):**
- `listStyle`, `sectionHeaders`, `sectionFooters`, `sectionItemCounts`, `showsSeparators`. No per-row metadata.

**Populator (`src/ui/native/swiftkit_overrides.cr:751 populate_list_view`):**
- Emits list style, separators, and per-section parallel arrays. No per-row callback emission.

### What's missing for the brief's plan

To support **per-row tap + per-row leading swipe + per-row trailing swipe + drag-reorder**:

1. **Crystal `UI::ListView` properties** (in `src/ui/views/list_view.cr`):
   - `on_item_tap_simple : Proc(Int32, Nil)?` — the brief calls for `Proc(Int32, Nil)` semantics (flat row index). The existing `on_item_tap : Proc(Int32, Int32, Nil)?` takes (section, item). We add a NEW flat-index callback because the new flat row-index semantics matches SwiftUI's `.onTapGesture` per-row pattern and the Voyager todos demo uses a single section. Naming: `on_row_tap : Proc(Int32, Nil)?` to avoid name collision.
   - `on_move : Proc(Int32, Int32, Nil)?` — (from_index, to_index) for the SwiftUI `.onMove` callback.
   - `leading_swipe_actions : Proc(Int32, Array(UI::SwipeAction))?` — lambda returning leading-edge actions for the row at index N.
   - `trailing_swipe_actions : Proc(Int32, Array(UI::SwipeAction))?` — lambda returning trailing-edge actions for the row at index N.

2. **`ListViewOverrides.swift` — new objc fields:**
   - `rowTapTokens : [NSNumber]` — parallel to flat childViews; 0 = no tap.
   - `moveToken : NSNumber?` — fires from the `.onMove` closure; we encode the (from,to) pair as a single Float64 token-value (high-32 = from, low-32 = to) OR emit two separate callback fires via a string-channel callback. **Decision:** use a string-channel callback — `UI::CallbackRegistry.register_string` accepts `Proc(String, Nil)`, and we send `"from=3,to=5"`. The string-channel keeps the bridge generic.
   - Per-row swipe arrays: flat-indexed parallel arrays (same shape as `SwipeActionRowFacade.leadingLabels` etc., one entry per row):
     - `leadingActionLabels: [[String]]` (nested per-row), `leadingActionIcons`, `leadingActionRoles`, `leadingActionTints`, `leadingActionTokens: [[NSNumber]]`
     - Same five for `trailing*`
   - These are nested arrays so the facade walks per-row and emits a `.swipeActions(edge:) { ForEach... }` modifier for each row.

3. **`ListViewFacade.swift` — apply modifiers per row:**
   - In `rowBuilder`, wrap the `APSKHostedChild` in:
     - `.onTapGesture { CallbackBridge.fire(token: rowTapTokens[absIdx], value: 0.0) }` when token != 0
     - `.swipeActions(edge: .leading, allowsFullSwipe: true) { ... }` when leading actions for that row are non-empty
     - `.swipeActions(edge: .trailing, allowsFullSwipe: true) { ... }` when trailing actions for that row are non-empty
   - On the outer `List`, add `.onMove(perform:)` when moveToken != nil. SwiftUI's `.onMove(perform:)` is only honored inside a `ForEach` (not the outer List), so it goes on the `ForEach(0..<cnt)` inside `Section`. SwiftUI also requires the user to enter Edit mode (via `EditButton()` or programmatic `editMode`) on iOS — **but** long-press-drag works without entering edit mode in iOS 15+ when `.onMove` is attached to a `ForEach` inside a `List` (verified in Apple's SwiftUI docs).

4. **UIKit renderer `visit(UI::ListView)` updates:**
   - For each item, register `on_row_tap` callback if set (the screen wires a single closure that takes the absolute row index and dispatches `:edit_row` with that index's todo id).
   - Build a flat `rowTapTokens` array.
   - For each item, call `leading_swipe_actions.try(&.call(idx))` and register each `SwipeAction.on_tap` proc; build the nested arrays.
   - Same for `trailing_swipe_actions`.
   - If `on_move` set, register a `register_string` callback that parses "from=N,to=M" and forwards to the proc.

5. **objc bridge entry points:**
   - No new C funcs needed — all setters use the existing array senders (`set_string_array`, `set_uint64_array`).
   - The only NEW shape is nested arrays. The simpler encoding: flatten the nested arrays into (flat, counts) form (parallel to `sectionItemCounts`). E.g. `leadingActionLabels` becomes a single `[String]` of length `sum(per_row_counts)`, with a parallel `leadingActionCounts: [NSNumber]` giving the per-row action count. This requires no new objc bridge funcs.

### Confirmed approach

The brief says "the SwiftKit populator gains the new fields + token arrays (parallel labels / icons / tokens / roles per row, OR a more compact per-row override array)." I'm choosing the **flat + counts** encoding — it reuses existing array senders, mirrors the section-flattening pattern the facade already uses, and adds zero new C entry points.

---

## 4. Full-swipe primary action ordering — confirmed

From the brief:

> SwiftUI's full-swipe fires the **first** action in the closure for that edge.
>
> But visually we want Edit on the leftmost tile (closest to row body). SwiftUI renders the modifier's first action **rightmost** by default. So tile order in the closure: `Delete, Mark Done, Share, Edit` to get visual order (left→right) Edit, Share, Mark Done, Delete.

**Confirmed.** The Crystal side will build:

```crystal
trailing_actions = [delete_action, mark_done_action, share_action, edit_action]
```

so SwiftUI iterates them in declaration order, places the first (`Delete`) at the rightmost (outermost) position closest to the edge being swiped from, and fires it on full-swipe-from-trailing. Visual order left→right when the row is fully swiped: `Edit, Share, Mark Done, Delete`.

For leading: `leading_actions = [archive_action]` — single tile, full-swipe fires Archive.

The visual order rule is a SwiftUI-rendering invariant the populator only needs to honor by ordering the Crystal-side array correctly. The facade ForEach iterates in array order.

---

## 5. Effort estimates per deliverable

| Deliverable | Estimate | Risk |
|---|---|---|
| D0 (this preflight) | done | — |
| D1 — rename | 2.5 hrs | mechanical; rg + sed-style edits across 72 files; spec fixtures need file renames; the `class_c_bootstrap.cr` (121 occurrences) is the heaviest single file |
| D2 — "before" screenshot | 0.5 hr | requires iOS build + simctl path proven |
| D3 — ListView extension (4 sub-commits) | **2.0 hrs** | longest single block; nested-array flattening + Swift facade work + token registration in renderer |
| D4 — todos row rebuild | 1.0 hr | replaces existing build_todo_row body; controller already has `move_row` |
| D5 — Mark Done in detail screen | 0.5 hr | one button + controller wiring |
| D6 — humanize_deadline | 0.25 hr | tiny helper |
| D7 — screenshot set (7 captures) | 1.0 hr | each capture is ≈8 min including the swipe gestures via simctl |
| D8 — hand-test guide | 0.5 hr | template the refocus guide |

**Total estimate: ~8 hrs.** The owner is gone for ~1 hour, so the full arc will NOT complete in that window. The implementer will commit progress at every STOP-commit checkpoint so the owner can pick up where this leaves off OR dispatch a follow-up agent.

### Drag-reorder feasibility (CRITICAL — brief flag at >2 hours)

**Verdict: feasible within the 2-hour D3 budget IF** the nested-array encoding works. The full plan:

- New Crystal property `on_move` (Proc).
- New facade overrides field `moveToken` (single token).
- New populator emission of `:setMoveToken`.
- New `.onMove(perform:)` modifier on the `ForEach` inside ListViewFacade.
- Crystal-side string-channel callback fires `proc.call(from, to)` after parsing "from=N,to=M".

**Risk: SwiftUI's `.onMove` on iOS without `EditButton()` requires long-press-drag.** Mail-app reorder is long-press-drag and matches the owner's expectation. SwiftUI on iOS 15+ supports this out of the box when `.onMove` is attached to a `ForEach` inside a `List`. No special editMode wiring needed for the long-press path.

**No blocker identified.** Drag-reorder proceeds in D3.

---

## Open questions / brief assumptions to flag

1. **`on_item_tap` already exists with `(section, item)` signature.** Brief calls for `Proc(Int32, Nil)` (flat-index). Adding a new property `on_row_tap` is the cleanest path — keeps the existing (section, item) API for callers that want it, gives the new flat-index API a fresh name. Spec'd above as `on_row_tap`.

2. **Voyager's `move_todo(from, to)` already exists** and uses visible-index semantics. Brief's `on_move` semantics align: SwiftUI `.onMove` passes `IndexSet, Int` (the dragged source index set + the destination). For a single-row drag the set has one element. We pass `(from=set.first!, to=destination)`. The facade encodes "from=N,to=M" as the string-channel value.

3. **Existing `UI::SwipeActionRow` capability declarations on `:swipe_actions`** stay valid — `UI::SwipeActionRow` still ships, still routes via the registry for callers that want a single-row swipe widget. The new `UI::ListView` path is a SECOND valid widget for the same intent_id. The intent registry currently maps `:swipe_actions` to ONE widget per platform; the todos screen will bypass the registry and use `UI::ListView` directly. The brief explicitly notes this is acceptable.

4. **`active_screen_class` ScreenContext property** — the current todos screen sets `context.active_screen_class = self.class` before the resolver call. After the rename, this property name stays (`active_screen_class` is descriptive, not Intent-specific), but the docstrings get updated.

---

## STOP commit checkpoint

This preflight is the first artifact and the first commit. The implementer commits it before any rename / bridge work begins.

— Implementer (Claude Opus 4.7), 10D-final preflight, 2026-05-27
