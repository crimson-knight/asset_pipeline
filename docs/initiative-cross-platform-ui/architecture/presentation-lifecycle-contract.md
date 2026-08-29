# Presentation-lifecycle contract

**Status:** Authoritative invariant for every widget in the catalog that has presented state (modal-presented, popover-presented, sheet-presented, alert-presented, action-sheet-presented).

**Owner directive (2026-05-28):** "When you click a to-do the action sheet opens and then stays open until I do something to trigger it to close. I think there's actually a lot more nuance in here that we're missing like that."

This document codifies that nuance as a binding contract. Every widget listed below must satisfy this contract. Bugs that violate it are P1 blockers against the [merge-readiness gate](../merge-readiness-gate.md).

## The invariant (plain English)

> A modal-presented view STAYS PRESENTED across any number of Rerender cycles until exactly one of the following explicit dismiss triggers fires:
>
> 1. The user taps a button inside the modal whose action results in a `SystemAction.perform(:dismiss_*)` call OR an `ActionResult.pop`.
> 2. The user performs a platform-native dismissal gesture (swipe-down on a sheet that allows interactive dismissal, tap-outside on a popover, escape key on macOS).
> 3. The controller explicitly mutates the presented-state flag to `false` and that mutation reaches the renderer.
>
> Re-rendering the containing screen — for ANY other reason than the three above — MUST NOT dismiss the modal.

The contract applies to: `UI::Sheet`, `UI::Popover`, `UI::Alert`, `UI::ConfirmationDialog` (action sheet), `UI::FullScreenCover`, `UI::Inspector`, and any future widget that presents content via a SwiftUI presentation modifier or a UIKit presentation controller.

## Why this contract exists

The asset_pipeline native renderer uses a Crystal-side `ActionResult.rerender` to propagate state changes. Rerender today rebuilds the view tree top-down, which produces a fresh SwiftUI view value at every node. SwiftUI's presentation modifiers (`.sheet(isPresented:)`, `.popover(isPresented:)`, `.confirmationDialog(isPresented:)`) are bound to `@State` cells inside the SwiftUI view; when the parent view value changes identity, the binding's state cell can reset, which in turn dismisses the presented content.

The naive symptom: tap a row → controller writes `pending_action_sheet_id = X` → Rerender → SwiftUI presents the action sheet → during the same runloop the binding callback writes `false` back through the `BoolStorage` (see `src/ui/renderers/uikit_renderer.cr:1717-1718`, `1840`, `3807`) → action sheet dismisses before the user can interact.

The contract is therefore a formal statement of what the renderer must guarantee against Rerender churn.

## The contract in formal terms

### C1 — Presentation state survives Rerender

For any view `V` with `V.is_presented == true` at runloop tick `t`:

- IF `V.is_presented` is NOT mutated by application code between `t` and `t+1`, THEN at `t+1` the native presentation MUST still be visible.
- The renderer's `visit(view : V)` method MUST NOT cause the underlying SwiftUI binding to drop `true` and emit `false` during a Rerender pass.

### C2 — Presentation state binding is one-directional during Rerender

The Crystal-side `is_presented` property is the source of truth. The SwiftUI binding is downstream.

- A Rerender pass MUST write Crystal's `is_presented` value TO the binding.
- A Rerender pass MUST NOT read the binding back into Crystal during the same pass.
- The binding's `set` callback (firing when the user dismisses) MUST queue a deferred `BoolStorage.binding` write that lands AFTER the current Rerender pass completes.

### C3 — Dismissal token is the only path that mutates Crystal state

When the user dismisses a presented view, the dismissal MUST flow through the `dismissToken` callback registered with `CallbackBridge.fire(token:, value:)`. The dismissal handler in Crystal MUST:

1. Set the appropriate state flag to `false` (e.g., `state.pending_action_sheet_id = nil`).
2. Return `ActionResult.rerender` so the renderer sees the new state on the next pass.

The dismissal must NOT be a side effect of SwiftUI's binding writing back during a Rerender — that path is forbidden by C2.

### C4 — Anchor views survive their host's Rerender

For widgets that anchor to a specific UIView (e.g., popover with `anchor_source_view`):

- The anchor's `NativeHandle` MUST be preserved across Rerender as long as the anchor view's Crystal-side identity is unchanged.
- The renderer MUST NOT release-and-recreate the anchor UIView during a Rerender pass.
- If the anchor view's Crystal-side identity changes (different object), the renderer MAY recreate the anchor, but MUST dismiss the popover via the dismissal token first.

### C5 — Action callbacks run AFTER dismissal completes

When a user taps an action inside a presented view (e.g., a button inside an action sheet):

- The native platform's animated dismissal MUST complete before the Crystal action handler fires.
- The action handler's `ActionResult.rerender` MUST be applied AFTER the platform has released the presentation controller.

This prevents the "double dismiss" race where the action handler resets state to default while the platform is still animating dismissal, causing a flash of the empty state or a re-present.

## Per-widget contract addenda

Each widget's usage doc at `.claude/skills/apple-platform-guide/usage/<widget>.md` MUST cite this document and, in the "Behavior contract" section, name the exact `is_presented`-equivalent property name and the dismissal callback property name.

For widgets with non-binary presented state (e.g., `Inspector` with split positions, `Sheet` with detents), the contract extends: the secondary state (split position, current detent) is subject to the same survives-Rerender invariant.

## How this gets enforced

The [interaction-contracts harness](interaction-contracts-harness.md) is the mechanical enforcer. Per widget, the harness asserts:

- **C1 spec:** present the widget → trigger N Rerenders via controller actions that are unrelated to the widget → assert the widget is still visible after Rerender N.
- **C2 spec:** instrument the BoolStorage to log every binding read during a Rerender pass → assert zero reads occur during the Rerender pass.
- **C3 spec:** dismiss the widget by tapping its dismiss action → assert exactly one dismissalToken fire → assert the Crystal-side flag is false on the next tick.
- **C4 spec:** for anchored popovers, present → trigger Rerender on the host → assert the anchor UIView's NativeHandle.ptr is unchanged.
- **C5 spec:** tap an action inside the presented view → instrument the action handler to log timestamp → assert the timestamp is after the platform's `presentationControllerDidDismiss` delegate fires.

## Today's known violations (P1 blockers)

Filed against this contract on 2026-05-28 after owner hand-test of iter-2:

- **V1 — Action sheet auto-closes on row tap (`UI::ConfirmationDialog`).** Tapping a Voyager todo row opens the action sheet then immediately dismisses it. Suspected violation of C1 + C2. Owner-reported.
- **V2 — Header sort buttons crash (`UI::Button` cluster in `TodosScreen` toolbar).** Tapping the three buttons at the top of the todos screen crashes the app. Suspected violation: an action callback firing into a dispatcher with stale state OR an anchored popover with a recycled anchor view violating C4. Owner-reported, needs stack trace.

Each violation must be reproduced by an interaction-contract spec BEFORE the fix lands. The spec is the regression test.

### V1/V2 source-of-truth location (Phase 12.A Codex review fix)

**Important honesty correction surfaced by Codex's Phase 12.A antagonist review (`handoff/2026-05-28-codex-phase-12a-review.md` BLOCKER 1):**

V1 and V2 manifested in the owner's hand-test against the `phase-10-d-polish` worktree, where Voyager's todos screen had been extended with an action sheet on row tap, sort filters in the header, and an overflow popover. **The main checkout of `phase-10-d-refocus` does NOT contain this code** (see `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr` — tap_btn navigates to editor, no ConfirmationDialog, header has only Print + Settings buttons).

Therefore:

- **V1 + V2 specs at `spec/native_ios/ui_interaction/{confirmation_dialog,voyager_toolbar}_spec.cr` are pre-staged for the polish-worktree merge.** They pend until both (a) the worktree's todos extensions land in main AND (b) tap coordinates are captured for the new ids.
- **The harness itself is validated by `spec/native_ios/ui_interaction/harness_smoke_spec.cr`** — a smoke test against current-main code (Voyager launches → emits launch marker → harness sees it). This is the executable proof Phase 12.A delivers.
- **V1 + V2 fix work moves to Phase 12.B**, scoped specifically to "merge the polish worktree, then reproduce + fix V1 + V2 using the harness".

This is a legitimate Codex BLOCKER 1 correction. The architect's session summary claims that Phase 12.A delivered the harness but did not yet reproduce V1 are now accurate; the spec scaffolding doc-claimed-as-reproducing is corrected here.

### Phase 12.C iter-2 — open lifecycle hazards deferred to 12.D

Codex's antagonist review of Phase 12.C iter-2 (commit `34a87c78`) flagged
three lifecycle hazards that are real but out of scope for the V1
auto-dismiss fix. Each is logged here so it lands explicitly on Phase
12.D's slate:

- **C5 ordering — action-fire vs platform-dismiss completion.**
  ConfirmationDialog's chosen actions call `CallbackBridge.fire(token, …)`
  synchronously from the SwiftUI button closure
  (`swift/.../Facades/ConfirmationDialogFacade.swift` multi-action +
  binary paths). Voyager controllers clear `pending_*_id` state and
  return `Rerender` synchronously inside that fire path. C5 says
  Crystal-side state mutation MUST follow the platform's dismissal
  COMPLETION callback — today's path mutates state before SwiftUI has
  finished its `.confirmationDialog` dismiss animation. Fix scope:
  dispatcher async pattern + iOS completion-handler bridge. Phase 12.D.

- **Dismiss animation not proven complete before tree swap.** The
  cross-render sweep flips bindings on the main thread (via
  `apskMainAsync`'s sync fast-path), but SwiftUI's actual dismiss
  animation continues across runloop ticks. The host's tree swap
  (`UIViewRepresentable.updateUIView` on iOS,
  `setContentView:` on macOS) tears the old hosting view down before
  the animation completes — visually acceptable for V1 (the user
  WANTS the modal gone) but logged for the completion-handler
  follow-up.

- **Main-thread invariant documented, not enforced.** The sweep
  reads mutable NativeHandle fields with the
  "NativeHandle is not thread-safe" caveat the type itself declares.
  Today both Voyager hosts enter on main; future off-main hosts
  would race. Phase 12.D candidate: add a debug-build assertion via
  `Thread.is_main_thread`.

These are tracked-and-deferred, NOT punted. The V1 auto-dismiss spec
should pass with the iter-2 sweep + identity logic in place; the
deferred items are about polish, ordering proofs, and future-host
safety.

### Phase 12.C iter-3 — additional Codex findings (Phase 12.D)

Codex iter-3 (commit `9d681e29` review) gave **READY for UIKit/Voyager
V1 hand-test**, **NOT READY for cross-platform Phase 12.C** until the
following land:

- **Popover sweep coverage.** `UIKit::Renderer#visit(UI::Popover)`
  calls the non-reactive `apsk_make_popover`; the handle never gets
  `state_handle` / `reactive_kind` / `presentation_identity`. Voyager's
  overflow popover has `test_id = "voyager-todos-overflow-popover"`
  but that ID is currently anchor metadata only, NOT sweep identity.
  V2 (overflow popover buttons crash) is a button-tap-chain bug, NOT
  a popover lifecycle issue — so this gap does not block V2's fix
  scope. But a Popover that gets stranded by an unrelated Rerender
  would still tear down with cause=tree-removal. Phase 12.D: add
  `apsk_make_popover_reactive` + `apsk_popover_set_presented` Swift +
  Crystal bridges + tag handles `:popover`.

- **Path B + Path A double-mark.** `UI::Sheet#dismiss!` emits
  `programmatic-dismiss`; if the next rerender removes the same
  identity, the sweep then emits `programmatic-dismiss-on-rerender`
  for the same logical dismissal. Voyager doesn't currently call
  `dismiss!` directly, so this isn't observable today. Phase 12.D:
  either suppress the sweep marker for handles that Path B already
  marked, or document the dedup expectation in the harness.

These two are explicitly downstream of V1's fix scope.

### Phase 12.D — continuing-presentation reuse (DELIVERED)

The Phase 12.C sweep made an unrelated Rerender stop *closing* a
continuing sheet, but the surviving sheet still suffered a
re-present: the host's destructive tree swap tore out the old hosting
view and the fresh tree mounted a new one at the same identity (the
"known limitation that proper view reconciliation would eliminate"
note in `native_view.cr#dismiss_reactive_presentations!`). Phase 12.D
closes that residual so SwiftUI never observes a dismissal at all.

- **Mechanism.** A sheet in the fresh tree whose `presentation_identity`
  matches a reactive sheet in the prior tree now REUSES the prior
  `NativeView` subtree verbatim — its NSHostingView/UIHostingView **and**
  its SwiftKit state handle are carried across the destructive
  re-render. `UIKit::Renderer#try_reuse` / `AppKit#appkit_try_reuse`
  mark the carried node `reused = true`, copy the surviving handle's
  `state_handle` onto the FRESH tree's `UI::Sheet` (so a controller
  closing the post-rerender instance drives the SAME binding — the
  state-sync fix), and emit `[APIC:Sheet:continuing-presentation-reused]`.

- **Host-facing API.** Construct the next render's renderer with
  `UI::UIKit::Renderer.new(reuse_from: prior_root)` (the prior render's
  root `NativeView`); the renderer builds the identity-keyed registry
  internally via `NativeView.build_reuse_registry`. After swapping in
  the fresh root, the host calls `renderer.retire_prior!(fresh_root)`,
  which detaches the reused subtree from the prior tree (no
  double-release of the shared handle) and runs the existing
  identity-aware orphan sweep. This is the PLAIN-host entry point — a
  host like `happy_coach`'s `render_current` no longer needs to
  hand-roll the registry/detach/sweep ceremony. The Voyager sample
  hosts keep their explicit `reuse_registry:` path (now built via the
  same `build_reuse_registry` helper) for backward compatibility.

- **v1 content policy.** The reuse path returns the prior render's
  presentation shell **and its prior content subtree** — the fresh
  tree's rebuilt content for that sheet is discarded (marker field
  `content=prior-shell-retained`). Re-rendering changed content INTO a
  reused shell requires child reconciliation (Stage 3 of the in-place
  reconciliation design) and is explicitly out of scope for v1. This is
  safe (no dangling pointers) and correct for the common case where a
  sheet's content is stable while it is presented; a host that needs
  live content updates inside an open sheet should drive them through
  the content widgets' own reactive setters (e.g. `Label#text=`), not a
  full screen Rerender.

- **Orphaned sheets unchanged.** A sheet whose identity vanished from
  the fresh tree is NOT reused; it keeps the Phase 12.C
  `dismiss_reactive_presentations!` orphan behaviour (clean
  binding-dismiss, not tree-removal).

- **Both renderers.** UIKit (iOS) and AppKit (macOS) both ship the
  reuse path symmetrically.

## Cross-references

- [merge-readiness-gate.md](../merge-readiness-gate.md) — the gate this contract feeds into
- [interaction-contracts-harness.md](interaction-contracts-harness.md) — the harness that mechanically enforces this contract
- `src/ui/renderers/uikit_renderer.cr:1717-1840` — BoolStorage + isPresented binding wiring
- `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/PopoverFacade.swift:48-100` — SwiftUI popover binding storage
- `swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Facades/SheetFacade.swift` — SwiftUI sheet binding storage

— Architect (Claude Opus 4.7), presentation-lifecycle-contract v1, 2026-05-28
