# Android native view-state contract

Status: development implementation; full Tier A renderer support remains open.

`NativeScreenHost` is the canonical Activity-owned mount used by the sample and
the Android CLI template. It preserves bounded native presentation state while
Crystal continues to own application values. This is full-tree replacement with
conservative restoration, not an in-place reconciler.

## Identity and matching

Set `UI::View#state_key` to an application-defined, nonempty identifier of at
most 256 UTF-8 bytes. It is independent of `test_id` and accessibility content.
Use stable identifiers, never entered text, credentials or other private values.
The route and keys are saved metadata, not encrypted application storage.

Keyed state matches only the same native kind and navigation scope. It can
survive sibling insertion. An unkeyed node matches its semantic position only
when the entire semantic tree shape is unchanged. Native bounds wrappers,
Material internal children and the inner horizontal scroll viewport do not
create additional shared-view positions. Duplicate addresses are ambiguous;
neither duplicate is restored.

A retained `NavigationStack` scopes its current page by that page's explicit
`state_key`, or by a monotonically allocated Crystal identity combined with a
Kotlin process nonce. Heap-address reuse and allocation-sequence reuse after
process restart cannot identify another page. Process-local scopes intentionally
do not restore after process replacement. Applications must provide stable
screen keys, restore their domain state and reconstruct the appropriate route
before expecting cross-process presentation restoration.

## What is preserved

- Focus and selection for native `EditText`, Material and SearchView editors.
- Keyboard focus on shared non-editor native targets, including the menu Picker's
  Spinner, plus exact focused RadioGroup/SegmentedControl options. Other internal
  compound children are not independently modeled.
- Horizontal/vertical scroll offsets, including the two-axis scroll container.
- Host viewport offsets when route and screen scope match.
- Requested keyboard visibility when a matched editor and focused window exist.
- Up to eight recent screen snapshots for navigation Back.

Selection is clamped to the current Crystal-controlled text length. Restoration
does not assign text to an editor. Saved password-field selections are omitted.
Metadata excludes native objects, Activity/Context references, callbacks and
editor strings. The canonical host disables framework hierarchy saving beneath
its Crystal-owned root, preventing a second `EditText` text snapshot based on
transient Android view IDs. Android documents this subtree behavior in
[View.setSaveFromParentEnabled](https://developer.android.com/reference/android/view/View#setSaveFromParentEnabled(boolean)).

The Activity writes the versioned state through `NativeScreenHost.saveState`
before its superclass save callback. On recreation, metadata can wait through an
initial asynchronous loading screen until a matching keyed screen appears.
Closing a host removes pending pre-draw listeners and clears its value history.
An eligible shared `focused = true` request takes priority over saved native
focus after mounting. See the [semantics contract](android-semantics.md).
After restoring scroll offsets, an explicit focus request asks every scrollable
ancestor to reveal the new target. This prevents the prior viewport from moving
a newly focused editor back offscreen, including inside nested two-axis scrolls.

Radio/segmented option focus uses an ordinal plus a SHA-256 signature of the
entire ordered native option catalog. A changed/reordered catalog invalidates
the locator; it does not focus whatever now happens to occupy the old ordinal.
Selection stays owned by Crystal and is not changed by restoring input focus.
The catalog is bounded to 256 options, 4096 UTF-16 units per caption and 32 KiB
UTF-8 total. Unsupported/over-budget compound shapes skip restoration. Saved
metadata contains the ordinal/signature, not option captions or native IDs.
The signature is a change detector, not encryption; do not treat option labels
or saved identity metadata as secret storage. Older v1 bundles without the two
optional child-locator fields remain readable; incomplete, mistyped or invalid
extensions fail closed without logging their contents.

Capture checks application visibility only up to the mounted root. A stopped
Activity's hidden window must not erase the editor state captured when that
Activity starts again. Explicitly hidden fields/ancestors and disabled fields
are still excluded. Restoration waits for the new tree's pre-draw and checks
actual display visibility. See Android's
[ancestor visibility contract](https://android.googlesource.com/platform/frameworks/base/+/android-7.1.1_r43/core/java/android/view/View.java)
for the distinction from `isShown()`; the stopped-window case is also asserted
against the real API 35 host.

## Active composition

`CrystalBridge.RefreshCause.STATE` requests are deferred while the focused
editor has an active composing span. The Activity retries while visible. No
partial native rebuild begins while that deferred branch is active. After
composition ends, the latest Crystal model is rendered and presentation state
is restored onto the replacement tree.

Explicit `ACTION` refreshes may replace the tree immediately. Text callbacks
update the Crystal value without independently forcing a whole-tree refresh.
This policy intentionally delays other on-screen asynchronous updates during
composition; it does not provide simultaneous in-place updates of sibling
views. The test holds a genuine input-connection batch across the asynchronous
deadline, then finishes composition and checks replacement/restoration.
Ending the outermost batch returns false on API 33+. Android documents an
EditText off-by-one through API 32 that returns true for that same final-batch
operation. End exactly once per begun batch; do not drain an extra batch based
on the older return. See [InputConnection.endBatchEdit](https://developer.android.com/reference/android/view/inputmethod/InputConnection#endBatchEdit())
and the [API 31 validation](android-input-api31-proof-2026-09-06.md).

## Bounds and failure behavior

Traversal has separate native-node, shared-node, depth and scope limits:
8,192 native nodes, 1,024 shared nodes, depth 128 and 4,096 UTF-8 scope bytes.
A snapshot contains at most 256 entries and 32,768 UTF-8 address bytes. Stored
history also has an aggregate address-byte bound. Its actual serialized Bundle,
including the current snapshot and nested-record overhead, is capped at 192 KiB
by dropping older histories; an oversized current snapshot is skipped. This
leaves room for the Activity's other state instead of budgeting just key strings.
Offsets must be finite,
nonnegative and no greater than one million logical units. Selection positions
must be -1 or within the corresponding integer bound.

An over-budget traversal raises the dedicated state-budget signal. The host
records a skipped snapshot and emits a fixed warning without keys, routes or
entered values, then continues ordinary rendering without promising preserved
state. Configuration errors and native/JNI exceptions are not reclassified as
state-budget fallbacks.

Saved-state decoding rejects unknown versions, incorrect field types,
duplicates, invalid hashes, oversized keys, nonfinite offsets and missing
required fields. It reads raw types to avoid typed Bundle getters logging a
mismatched saved value. It does not log exception contents.

## Validation and remaining scope

The mandatory smoke runner includes pure matching/history tests, shared Crystal
fixture/identity tests and real Android view-state tests. Native tests cover
composition, keyed insertion, recreation, two-axis scrolling, page isolation,
Back restoration, malformed saved metadata, password-selection omission and
over-budget refresh fallback. Serialized metadata and actual framework
hierarchy bytes are checked for synthetic editor text; a positive control
enables framework saving and proves that the same byte check detects its copy.

The generated application's test independently checks its keyed editor through
recreation and native navigation. This must pass from a fresh CLI-generated
consumer without repairing generated output.

Not covered by this contract: in-place reconciliation, all focusable widget
kinds, search widgets, user-requested focus modifiers, automatic domain/route
restoration, process-death survival of unpersisted application data, accessibility
parity, oversized-tree state retention or physical-device compatibility. These
remain separate implementation and proof gates in the
[full Android plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).
