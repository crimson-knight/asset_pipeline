# Android native sheet contract

Status: bounded development implementation. This replaces the inline Sheet
preview with a real native window; it does not promote the entire Android
renderer, modal catalog or device matrix to supported Tier A.

## Presentation

`UI::Sheet` renders an invisible declaration whose single content root is owned
by the Crystal native tree. `NativeScreenHost` moves that content into an
Activity-owned Material `BottomSheetDialog`. Controls inside it remain real
Android Views using the same Crystal callbacks and field values as the page.
There is no WebView or text-only sheet placeholder.

One active canonical modal is allowed across Sheet, Alert and
ConfirmationDialog. Simultaneous or nested active declarations fail explicitly;
applications must sequence them. Declarations under hidden page ancestors do
not present. Nested active modal declarations inside sheet content are rejected,
including declarations whose own ancestor visibility would otherwise hide them.

The native adapter uses Material's
[BottomSheetDialog](https://developer.android.com/reference/com/google/android/material/bottomsheet/BottomSheetDialog)
and [BottomSheetBehavior](https://developer.android.com/reference/com/google/android/material/bottomsheet/BottomSheetBehavior).
The current pinned Material dependency is 1.12.0.

| Shared detent | Three-height native state | Nominal window-relative height |
| --- | --- | --- |
| `:small` | collapsed | 25% parent-height peek |
| `:medium` | half expanded | 50% parent-height ratio |
| `:large` | expanded | full available sheet, below the status bar |

One to three unique detents may be declared; `selected_detent` must be included.
For one or two declared heights, Material uses content-fit endpoints: the
largest allowed height is expanded, and a second smaller allowed height is
collapsed. A small-only sheet is therefore natively expanded **at small height**,
not full-screen. This prevents a drag or nested content scroll from expanding
into an undeclared larger height. With all three heights declared, the native
collapsed/half/expanded states map directly to small/medium/large.

These percentages are nominal, not fixed pixel promises. In short windows or
with larger text, compact heights grow to fit measured enabled/focusable native
controls plus the handle and system exclusions, bounded by the available window.
The minimum control viewport is 48dp. Application-declared oversized controls
may still exceed the screen; integer-bounded geometry alone does not prove
usability. The logical selected detent does not change merely because its
adaptive pixel height grows.
Distinct logical detents can share a pixel height when window/keyboard bounds
leave no room between them; they are not guaranteed distinct physical stops.

Native settled heights update the Crystal property without rebuilding the
window during dragging. An unexpected half-expanded compact-set state is
normalized to the nearest allowed logical height; a distance tie chooses the
larger detent. `:custom` is rejected:
the shared Symbol API does not supply a numeric custom height.

`shows_drag_indicator` controls the real Material drag handle.
`interactive_dismiss_disabled` prevents Back, outside cancellation and native
hideability; explicit application closure remains available. Content uses a
native scrolling viewport whose measured height follows the actually visible
portion of the sheet, including while dragging. The larger offscreen portion
of a three-height native sheet is not counted as usable scrolling space.
Presented outer width/height/fill constraints are
rejected; constrain the content, not the invisible declaration. Material window
chrome is used; Apple-only `material_semantic` and inline `surface_style` are
not portable window-background overrides.

## Application state and dismissal

Set `is_presented` true and render/invalidate through the usual app boundary to
present a sheet. A setter alone does not create a new window immediately.
Keep the Sheet or its external presentation model in application state. A
factory that unconditionally creates a new presented Sheet on every render is
asking for it to reopen; callbacks must update any external Boolean too.

After presentation, `is_presented = false`, `dismiss!` and
`SheetPresenter.dismiss` schedule native closure. The host defers this work
until the current Crystal-to-Java call returns, preventing native re-entry.
It also flushes pending closure before rendering or background lifecycle work.

Actual dismissal retires the native window and event lease first, changes the
retained Sheet's presentation flag to false, and invokes `on_dismiss` once.
The framework's later cancellation/dismissal callback cannot invoke it again.
Explicit closure and removal/replacement of the declared sheet both complete
this contract. An ordinary same-identity render, background suspension,
Activity recreation or host teardown is silent.

Structural reconciliation uses the route and bounded declaration address, with
a SHA-256 identity in the Java host. The single-surface Crystal application
retains one retired Sheet declaration across render teardown, independently of
its already-retired callback tokens. A matching new declaration clears the
handoff silently. A removed or replaced one clears the handoff before invoking
application code, then requests another render before presenting a modal that
the callback may have changed. Activity teardown discards the handoff without
calling user code. Old native handles are still released through normal tree
teardown, not retained for structural callbacks.

`SheetPresenter.is_presenting` remains the presenter's explicit command state;
it is not automatically synchronized after a user dismisses its Sheet. Use
`sheet.is_presented` or `on_dismiss` for actual presentation state.

## Focus, keyboard, ownership and privacy

Same-screen asynchronous refresh waits for actual IME composition inside the
sheet to finish. Explicit user actions may commit a replacement. Matching
window content restores bounded focus, editor selection, scroll and IME state;
application field values stay in Crystal. Explicit focus requests take priority.

The sheet owns keyboard avoidance once: its window does not independently resize
for the IME, and content insets reserve the keyboard area. Compact heights rise
by the additional keyboard exclusion beyond the navigation bar, capped below
the status bar, without changing the logical selected detent. This preserves
their nominal usable height when the available window permits it; cramped
windows can still have less space.

Sheet editors request `IME_FLAG_NO_FULLSCREEN` while preserving their existing
action and other option bits. Compliant keyboards keep the editor in its native
sheet rather than replacing it with a fullscreen extraction screen; Android
explicitly allows third-party IMEs to ignore this request. See
[EditorInfo](https://developer.android.com/reference/android/view/inputmethod/EditorInfo#IME_FLAG_NO_FULLSCREEN).
If the open keyboard leaves too little room for the controls plus the optional
drag handle, the handle temporarily hides at its original native size and returns
when space returns. `shows_drag_indicator: false` never creates a handle.
This does not disable scrolling, change logical detents, or bypass locked
dismissal. A saved visible editor clears the window's initial hidden-keyboard
policy and posts its restoration request after window focus dispatch, following
[Android's visibility guidance](https://developer.android.com/develop/ui/views/touch-and-input/keyboard-input/visibility).

The canonical theme disables Material's automatic surface inset padding and
margins. The actual `onAttachedToWindow` override normalizes Material's two
outer containers and decor fitting after the library's own attachment hook;
doing this only after `show()` is too early. Application content padding is not
cleared. See the pinned library's
[attachment implementation](https://github.com/material-components/material-components-android/blob/1.12.0/lib/java/com/google/android/material/bottomsheet/BottomSheetDialog.java)
and [surface defaults](https://github.com/material-components/material-components-android/blob/1.12.0/lib/java/com/google/android/material/bottomsheet/res/values/styles.xml).

The page snapshot excludes sheet descendants, whose state belongs to the
separate window. The sheet's saved Bundle contains only the existing bounded
view-state metadata, with an encoded cap of 196,608 bytes. It does not serialize
editor values, Sheet content, callback tokens or Activities. The normal
view-state key/shape/sensitive-field rules still apply; do not use personal
content as application state keys. In-memory detent and presentation state
remain application-owned, not automatic process-persistent model storage.

Per-control event leases prevent retired editors, buttons, selectors and
semantic actions from reaching Crystal. The shared native tree can unregister
all subtree callbacks before releasing its handles. Window state, focus and
post-layout work use the checked native failure boundary. A failure is terminal
and retires the window; ordinary Activity teardown still releases root ownership.
Dismissal through a cached JNI environment rejects a different rendering thread.

## Verification and remaining promotion gates

`scripts/run_android_smoke.sh` requires the shared Sheet specs,
`SheetPolicyTest`, `AndroidSheetContractTest`, `AndroidSheetViewportTest`, and
`AndroidSheetWindowMatrixTest`. The separate Java failure
driver also runs `AndroidSheetFailureBoundaryTest` in a new terminal process.
CLI/AgentC drivers require the Sheet policy report, and package inspectors check
both native sheet configuration/dismissal exports and the structural-transition
entrypoints in both ABIs. A generated counter passing is integration regression,
not a claim that the counter UI itself contains a Sheet.

See the [initial window checkpoint](android-sheets-proof-2026-09-05.md) and
[viewport/allowed-height checkpoint](android-sheet-detents-proof-2026-09-05.md)
for exact executed tests and evidence. The latter proves all declared height
sets, bottom-action reachability, actual downward/locked gestures, and small-only
keyboard resizing/recreation/Back on the portrait API 35 ARM64 fixture.
The [cramped-window follow-up](android-sheet-window-matrix-proof-2026-09-05.md)
records the current enlarged-text/RTL/landscape implementation and its exact
verification status; do not treat an in-progress matrix as completed proof.
Remaining promotion work includes nested popup/control coverage, broader
size/device/API and keyboard matrices,
TalkBack exploration and accessibility focus. General modal stacking, custom
numeric detents and Apple surface effects are not claimed. Physical-device,
full Tier A, CI and public released-consumer gates remain open in the full plan.
