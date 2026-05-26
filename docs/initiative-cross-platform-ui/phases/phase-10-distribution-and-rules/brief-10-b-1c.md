# Phase 10B.1c — Android Material3 swipe integration

**Branch:** `phase-10-b-1c` from `phase-10` (tag `phase-10-batch-2-merged-2026-05-26`).
**Status:** v1. Predecessor: 10B.1a closed (InlineActionRow shipped). Concurrent-eligible with 10B.1b.

## Context

Currently `:swipe_actions` resolver raises `UnresolvableDefault` for `:android` — no default widget. 10B.1c installs the Android default: a Crystal widget that the Android renderer maps to **Material3 SwipeToDismiss** (or, if Material3 isn't reachable from the current JNI bridge, falls back to a horizontal LinearLayout of action buttons).

## Deliverables

1. **`UI::AndroidSwipeActionRow`** (or extend `UI::SwipeActionRow` with Android-specific rendering — recommend a NEW widget for clarity).
   - Reuse the `SwipeAction` value type from `swipe_action_row.cr`.
   - `declares_capabilities :swipe_actions, {...}` honestly reflecting Material3 SwipeToDismiss support.
2. **Android renderer dispatch** — `visit(view : UI::AndroidSwipeActionRow)` in `src/ui/renderers/android_renderer.cr`. First attempt: route through Material3 SwipeToDismiss via JNI. Fallback: horizontal LinearLayout (same pattern as `InlineActionRow` Android impl).
3. **Web/AppKit/UIKit dispatch** — stub implementations that delegate to fallback (web → `InlineActionRow`-like HTML; AppKit/UIKit → `InlineActionRow`-like stack).
4. **`src/ui/intent_bootstrap.cr`** — `:android → UI::AndroidSwipeActionRow` (no longer raises).
5. **Specs** — `spec/web/ui/views/android_swipe_action_row_spec.cr` (web fallback rendering test) + extend intent_spec.cr (`:android` resolves to the new widget).
6. **Close handoff** — Material3 SwipeToDismiss JNI status (works / blocked / deferred); fallback rationale.

## Workflow

1. `git checkout -b phase-10-b-1c phase-10`.
2. Read `src/ui/views/swipe_action_row.cr` + `inline_action_row.cr` + Android renderer (especially `visit(InlineActionRow)` for LinearLayout pattern).
3. Read `src/ui/native/android_bridge.cr` (or similar) to understand current JNI surface. Is Material3 SwipeToDismiss reachable? If yes, wire it. If no, ship fallback + document blocker.
4. Build the widget.
5. Wire all 4 renderers.
6. Update intent_bootstrap.
7. Specs + close handoff.
8. Standard footer.

## Acceptance

- ✅ `UI::AndroidSwipeActionRow` exists with `declares_capabilities`.
- ✅ All 4 renderers implement `visit`.
- ✅ `:swipe_actions` resolver returns the widget on `:android` (no longer raises).
- ✅ Material3 SwipeToDismiss attempted; status documented (verified / blocked / deferred).
- ✅ Specs pass.
- ✅ Lint + build green.
- ✅ Codex content review APPROVE.

## Out of scope

- Per-widget HIG validation (deferred).
- Other intent capabilities.

— Architect (Claude Opus 4.7), 10B.1c brief v1
