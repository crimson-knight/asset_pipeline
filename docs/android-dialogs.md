# Android native alert contract

Status: bounded development implementation, not complete modal or Tier A parity.
`UI::Alert` and `UI::ConfirmationDialog` now declare Activity-owned Android
windows. `UI::Sheet` now has a separate bounded
[native custom-content contract](android-sheets.md); it is not an Alert variant.

## Presentation and actions

The canonical `NativeScreenHost` discovers invisible, keyed dialog declarations
after mounting the native tree. One presented alert/confirmation/sheet is allowed per
screen; simultaneous declarations fail explicitly instead of choosing one or
stacking windows. Declarations under hidden ancestors do not present.

The host uses `MaterialAlertDialogBuilder` so the returned Android `AlertDialog`
uses the Activity's Material theme. This follows the
[Material builder contract](https://developer.android.com/reference/com/google/android/material/dialog/MaterialAlertDialogBuilder).
Actions are actual Android buttons, not buttons painted inside the page.

- An Alert supports one to three actions, styles `:default`, `:cancel`, and
  `:destructive`, with at most one cancel action. No supplied buttons means OK.
- ConfirmationDialog supplies its cancel and confirm actions. Destructive text
  uses the Material error color. Button placement follows native positive,
  neutral and negative slots rather than promising shared-array visual order.
- Tapping an action sets that retained Crystal view's `is_presented` false
  before invoking the supplied action. Back/outside cancellation invokes the
  Alert's cancel action, if any, or ConfirmationDialog's `on_cancel`, once.
- An application-driven change to `is_presented = false`, followed by a normal
  render, silently removes these alerts. It does not fabricate a user cancel.
- The application still owns external state. If a screen factory creates a new
  dialog from another Boolean on every render, its callbacks must also update
  that Boolean. The renderer cannot change unrelated application models.
- Explicit inline width/height/fill constraints on a presented alert are
  rejected. Native window sizing is platform-owned. Arbitrary shared surface,
  animation, gesture and shortcut modifiers are not window-level guarantees.

## Ownership and lifecycle

Before replacing a Crystal root, the screen host retires the old dialog's
dispatch lease, removes its button/cancel/dismiss listeners and closes the
window. Only then may native views and Crystal callback tokens be released.
Queued or stale actions cannot reuse retired tokens. Actual user dismissal also
retires the window before crossing back into Crystal, preventing a second
framework dismissal callback from dispatching again.

Backgrounding and Activity destruction close the window silently. Foreground
mounting can reopen it if the application still declares it presented.
Recreation saves only bounded keyed identity, a SHA-256 presentation digest and
the focused action's index. Titles, message text, button captions, callback
tokens, native Views and Activities are not placed in this Bundle. Focus is
restored only if route, identity and presentation match. This is keyboard focus,
not a claim of TalkBack accessibility-focus restoration or app model persistence.

The canonical checked-call failure path also retires live windows. A failed
session is terminal; normal Activity cleanup remains possible. There is no
production reset-to-success hook.

## Bounds and semantics

The internal JSON transport is capped at 16 KiB UTF-8. Title is nonblank and at
most 1024 bytes; body at most 8192 bytes; each action caption is nonblank and at
most 512 bytes. Callbacks are distinct positive signed-64-bit-compatible tokens.
Malformed native descriptor diagnostics do not echo packets or parser causes.

The dialog decor inherits declaration semantics and an accessibility pane title;
native buttons retain platform behavior and have a minimum height of 48 dp.
An ordinary declaration test ID produces `<id>.action.<index>`. If that would
exceed the existing 1024-byte semantics bound, `DialogPolicy.actionTestId`
provides a stable hash-based ID instead. Neither identifier is a spoken label.
Full accessible touch areas, large-text layouts, RTL, keyboard shortcuts and
TalkBack exploration remain separate promotion gates.

## Verification and related sheet work

`scripts/run_android_smoke.sh` includes shared serialization/fixture specs,
`DialogPolicyTest` and `AndroidDialogContractTest`. The isolated Java failure
lane starts with a live dialog and checks terminal retirement and native cleanup.
CLI-generated and AgentC Android test drivers require the canonical dialog
policy report; artifact inspectors require `android_dialog_configure` in both
native ABIs. A generated counter passing those gates is host regression, not a
claim that its own UI exercises dialogs.

The subsequent [Sheet implementation](android-sheets.md) adds real custom
content, detents, keyboard/window metadata and separate exactly-once dismissal
semantics, including structural removal. Its promotion limits and
[runtime proof](android-sheets-proof-2026-09-05.md) are tracked independently;
neither milestone completes full modal or Tier A parity.
