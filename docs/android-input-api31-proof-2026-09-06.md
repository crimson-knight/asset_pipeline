# Android input coordination and minimum-version probe — September 6, 2026

Development evidence; the full Android compile-target goal remains active.
Evidence root: `/tmp/ap-android-ime-proof.MD7civ`. Temporary local artifacts are
not public release artifacts or independent CI evidence.

## Input-test coordination

The preceding [CI/ownership checkpoint](android-ci-entrypoint-proof-2026-09-06.md)
retains the failed 48-test run, including the unexpected `Before\0éter…` edit.
Ten additional bounded diagnostic runs (`unicode-repeat-1.txt` through
`unicode-repeat-10.txt`) all pass with normal completion and no failure/skip
statuses. None produces the failure-only input trace. Repetition does not
establish the cause of the original edit or prove a production fix.

Inspection identifies a separate concrete test-protocol omission: the fixture
creates and drives its own direct InputConnection while Gboard also has a live
system-managed input session. It previously gave that session no notification
after replacing its surrounding text. Ending composition removes local spans;
it does not invalidate all queued edits from the other session.

`AndroidTextContractTest.publishExternalEdit` now notifies Android immediately
after each complete main-thread synthetic transaction, before queued IME
requests can run. It uses
[invalidateInput](https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#invalidateInput(android.view.View))
on API 33+ and the documented
[restartInput](https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#restartInput(android.view.View))
fallback on API 31/32. The single-line transaction includes Done submission;
the multiline transaction also notifies its attached keyboard. No production
per-keystroke restart, text replacement, keyboard suppression, timeout extension
or relaxed assertion is introduced. The bounded failure-only trace remains.

The old initial string's UTF-16 positions 7–8 contain `e` plus combining acute;
those positions contain `Af` in the expected final value. A stale composing
range would explain the observed substitution, but this remains an inference:
the original remote edit was not captured. Do not present it as traced causality.

`synchronized-input-build.txt` rebuilds the test APK. The focused result in
`synchronized-input-focused.txt` passes in 10.243 seconds on API 35 ARM64.
`input-source-sha256.txt` identifies the revised test source.

## Complete API 35 run

`make-native-final.txt` and `native-final/` record the actual public Make target
on the existing task-owned `emulator-5556`. This run includes the preceding
callback ownership and Sheet observation fixes plus the input coordination
above. The completed target exits zero:

- The 31-second build completes 123 tasks (12 executed, 111 up-to-date),
  rebuilding both native ABIs. The 93 JVM reports are validated but their
  execution is up-to-date; this is not a claim of 93 newly executed JVM tests.
- All **48 Android tests pass in 822.004 seconds**, with normal instrumentation
  completion and no failure/skip statuses. This includes the corrected Sheet
  settling/root-replacement observations and exact Unicode assertions.
- All six isolated Crystal failure cases pass, followed by 400 Java partial
  renders/original Throwable identity (13.056 seconds) and the Sheet window
  failure boundary (7.851 seconds). The final ordinary process is 23772 with
  initialized Crystal and CheckJNI, not an intentionally failed test session.
- `native-source-verification.txt` verifies all 512 source-ledger entries.
  Source and canonical package files are not modified during the run; the
  separate API 31 probe installs copies of these same APKs.

The debug APK is
`47453d4b5315e44dc1424b85766e985acd31ec19139452728625f696afa35065`;
test APK
`def411ba6a1525e8a79a001f29b284afe120471424c48788c17e37d280c8f6f0`;
App Bundle
`46c1124a7bbc5f87404640129e4187092f7ef63caed4c3d5b412b9ae3a8f3074`.
The passing checkpoint does not establish the uncaptured original edit's cause
or promote wider support/release claims.

## First API 31 device proof

Installed Google's `system-images;android-31;google_apis;arm64-v8a`, revision 11,
and created `ap_android31_20260906` under the task's own evidence directory.
The emulator uses port 5558, a Pixel 6 profile, 1080×2400 at 420 dpi, two cores,
2 GiB RAM, software rendering and `hw.keyboard=no`. Its AVD/user/emulator homes
are task-local, following Android's
[environment-variable contract](https://developer.android.com/tools/variables).
The existing emulators on ports 5554 and 5556, global keyboard selection and
existing AVD data are not changed. The system image is a retained SDK install.

`api31-first-launch.txt` records a successful cold launch (6.000 seconds).
The reviewed `api31-first-launch.png` shows the real Crystal-rendered native
interaction screen and its button/toggle/checkbox controls. The copied APKs
and their hashes are retained under `api31-package/` and
`api31-package-sha256.txt`. `api31-app-logcat.txt` contains initialized Crystal
and CheckJNI evidence for normal process 4232 and test processes 4614/6881;
no unexpected native/JVM runtime failure is observed in that retained log.

`api31-focused-instrumentation.txt` runs seven tests in 94.145 seconds:
**six pass, one fails**. Image assets, theme/system bars, logical dimensions,
Unicode composition/submission/multiline recreation, the measured layout
matrix and real two-axis scrolling pass. The Unicode test exercises the
API 31 `restartInput` fallback, not the newer invalidation API.

The initial interaction test fails its unchanged five-second keyboard readiness
gate: the editor is focused and visible but IME visibility/height remains false/0.
The show request reaches the system at 01:22:42.679. Gboard begins its input view
at 01:22:42.821 and logs first-use language/keyboard initialization plus skipped
202/119-frame intervals at 01:22:46.197/48.522. These observations support a
first-use readiness/timing hypothesis; they do not establish that the app's
inset handling is universally correct or that startup performance is acceptable.

The unchanged single test subsequently passes in 34.366 seconds
(`api31-keyboard-warm.txt`), including real keyboard visibility, key-by-key text,
callbacks and lifecycle assertions. This is a warm diagnostic pass, not an
erasure of the fresh-device failure. No keyboard was disabled/replaced, no
animation was turned off and no test timeout was changed to obtain it.

The timing/window/IME reports are retained separately. The attempted
`api31-keyboard-warm-during.png` capture occurred after instrumentation had
finished; its launcher image is **not** a keyboard-visible evidence capture.

## Generated-app composing-range defect

The actual generated counter from the preceding checkpoint was also rebuilt
and tested on API 31 with its own unmodified `test_android.sh`:
`api31-consumer-run.txt` / `api31-consumer/`. Its 34-second build completes
126 tasks (17 executed, 109 up-to-date), including both ABIs and release
packages. The generated, Amber and AssetPipeline ledgers all still match:
36 + 242 + 455 = 733 inputs. These consumer inputs exclude the sample-only
AndroidTextContractTest changed above.

Its 13-test run finishes in 16.987 seconds with **one failure**: the app test
expects `Android 雪 😀 é` immediately after appending Unicode, but receives
` 雪 😀 éd`. All 12 storage/Keystore/file tests pass. The driver correctly exits
one before process-restoration and final package inspection, so no completed
consumer/restoration checkpoint is claimed for this attempt.

The generated test moved its selection to the end without finishing the
keyboard's composing range. Android explicitly specifies that
[commitText replaces the composing range before considering selection](https://developer.android.com/reference/android/view/inputmethod/InputConnection#commitText(java.lang.CharSequence,int)).
The observed suffix replacing `Androi` is consistent with that contract. This
is a concrete generated-test protocol defect, distinct from the earlier
uncaptured asynchronous sample edit.

The canonical CLI template now asserts the typed `Android` prefix, establishes
a real composing span deterministically, finishes it without changing text,
asserts its removal, appends Unicode, then publishes the external edit to the
system IME using the same API 33+/31–32 distinction. Assertions for exact name,
validation, lifecycle, navigation and separate-process restoration remain.
No already generated application is manually repaired.

`cli-input-baseline.txt` records the new generator contract failing before the
template change. `cli-input-full-spec.txt` then passes **526 examples**, no
failures/errors/pending, in 15.0 seconds. Formatting and targeted whitespace
checks pass. `cli-input-source-sha256.txt` identifies the two changed CLI inputs.
The rebuilt actual CLI is `<evidence>/amber`, SHA-256
`e355e92f1f68561fb1632b768934bdf7d756f85785240a503371cc764270c330`.

### Fresh actual-CLI consumer on both Android versions

`fresh-api31-consumer.txt` creates a new project using that actual CLI at
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.v8T7kj`.
No generated-source repair is performed. Explicit local Amber/AssetPipeline
overrides make this development-consumer proof, not released-shard resolution.

- Two shared examples and real web state/validation/CSRF/escaping checks pass.
- The fresh 36-second Android build executes all 126 tasks. All **93 JVM tests**
  execute and pass in 15 reports, with zero failures/errors/skips. Both ABIs,
  debug/release APKs, App Bundle and matching native symbols pass inspection.
- On **API 31**, all **13 Android tests pass in 24.215 seconds**, followed by a
  separate exact-state restoration test in 2.693 seconds. Process 7553 persists
  count **4** and the exact Unicode name; process 7676 verifies it without
  saving/incrementing. Final ordinary process 7726 displays restored state.
- The same generated source then runs its own real build/test script on
  **API 35** (`fresh-consumer-api35-run.txt`, `fresh-consumer-api35/`). This
  26-second rebuild completes 126 tasks (3 executed, 123 up-to-date); JVM
  execution is reused, not claimed as fresh. All **13 Android tests pass in
  41.064 seconds**, then exact-state restoration passes in 5.960 seconds.
  Process 23927 saves count **32**; process 24064 verifies it; final normal
  process 24116 displays the restored count and `Android 雪 😀 é`.
- The relaunch screenshots for both APIs are visually reviewed. Exact Unicode
  is established by native assertions, not inferred from the screenshots/XML.
  All **733 input hashes** still match after both runs, including 36 generated,
  242 Amber and 455 AssetPipeline inputs. The original failed consumer source
  is preserved separately. The new template is not retrofitted into that app.

The completed API 31 generated-app run does not erase the sample's separate
first-use keyboard failure or substitute for its full native/failure matrix.

## API 31 full-matrix compatibility findings

`make-api31-native-final.txt` / `api31-native-final/` finish the first full
minimum-version invocation: **48 tests, four failures, 584.415 seconds**.
Make exits 2 before isolated failure lanes. All 512 source hashes match the
failed build (`api31-failed-source-verification.txt`). This is not a passing
required target, even though the generated consumer passes separately.

Two assertions (`AndroidViewStateTest` and `AndroidSheetContractTest`) require
`endBatchEdit()` to return false when ending the final batch. Android documents
an [EditText off-by-one corrected in API 33](https://developer.android.com/reference/android/view/inputmethod/InputConnection#endBatchEdit()):
the older implementation returns true for that same final-batch operation.
The composition/deferred-refresh assertions before the return-value check pass.
Both tests now assert the documented API-specific return, end exactly their one
opened batch and retain subsequent editor/selection/refresh/ownership checks.
They do not ignore the return, drain an extra batch or change production code.

The two other failures are English/Arabic large-font landscape Sheet checks.
They infer that a window must be cramped solely from font scale 2 plus landscape.
API 31's actual viewport is 299 pixels; its 225-pixel editor ends exactly at the
520-pixel keyboard top. The native handle is visible and the editor remains
fully visible, contrary to the test's hard-coded expected hidden handle.
The production policy already uses actual body/control/handle measurements,
not that font/orientation shortcut.

The revised test independently measures the fixture's six complete controls,
the handle and available space above the real IME/system bars. It asserts the
corresponding handle state and additionally requires a viewport large enough
for a complete control whenever the window permits. It never calls the
production policy to calculate its own expected answer. The diagnostics now
include available body, minimum viewport and actual handle height, distinguishing
both keep/hide cases across keyboard versions. Fixed text/focus/recreation and
Back assertions remain unchanged. `api-compat-source-sha256.txt` identifies the
three revised test inputs. Focused and complete post-correction results must be
recorded before promoting the minimum-version checkpoint.

The focused post-correction API 31 run now passes **all four tests in 123.755
seconds** (`api-compat-focused-31.txt`). API 35 passes the two independently
measured Sheet cases and the Sheet composition case, but its ViewState test
fails after tapping Insert sibling (`api-compat-focused-35.txt`: four tests,
one failure, 171.998 seconds). Its earlier composition, batch completion,
editor replacement, focus, selection and inner scroll assertions pass. The
failure is the subsequent visible-text wait, not the API-specific batch return.

That insertion failure remains **unexplained**. The test now emits a bounded,
failure-only synthetic-fixture diagnostic containing the actual Structure
label, native visibility/rectangle, inserted-node presence, host/inner scroll,
composing span and view-state counters. It does not retry the tap, increase the
five-second wait, force focus or alter the application's refresh policy.
Three focused diagnostic runs pass (23.659, 22.875 and 23.361 seconds), without
reproducing the failure or emitting that diagnostic. This is not causal proof
or a repair. The original failed result is retained. The API 35 all-48
instrumentation recheck now passes **48 tests in 881.540 seconds**, including
insertion, with normal completion and no failure/skip statuses
(`api35-compat-all-instrumentation.txt`). It uses the same already-installed
diagnostic APK; `api35-compat-package/` preserves both packages before the next
equal-width layout build. This is a complete instrumentation recheck, not a
second invocation of the full build/failure driver. Equal-width implementation
work starts after the API 31 driver completes and while this API 35 run is
finishing against its frozen package; those new sources are **not** covered by
this checkpoint. The earlier intermittent insertion failure remains unexplained.

## Complete post-correction API 31 target

`make-api31-compat-complete.txt` / `api31-compat-complete/` now finish the actual
required Make target with **exit 0** on `emulator-5558`:

- Build: 35 seconds, 123 tasks (two executed, 121 up-to-date). Both ABI builds
  and package inspections complete. The 93 JVM reports are validated but reused;
  they are not 93 new executions.
- **48 native tests pass in 700.571 seconds**, with normal instrumentation
  completion and no failure/skip statuses. This includes all four corrected
  API compatibility cases and the diagnostic-only ViewState test.
- All six Crystal failure processes pass with 100 partial-render cleanups each;
  malformed-semantic boundary probes remain included. The 400 Java partial
  renders and original Throwable check pass in 19.651 seconds, and the Sheet
  window-failure check passes in 9.397 seconds. Normal terminal cleanup and
  subsequent startup pass, with no unexpected runtime diagnostics.
- A separate ordinary process, **10729**, cold-launches in 2.304 seconds with
  Crystal initialized, CheckJNI enabled and the native interaction tree mounted.
  `relaunch.png` is visually inspected; it shows the actual Android controls.
- `api31-compat-source-verification.txt` verifies **all 512 source entries**
  after completion. No production source changes occurred during this run.

The debug APK and App Bundle remain byte-identical to the earlier passing API
35 checkpoint. The revised test APK is
`ebb14159569ea339979a2887a9e0a46c1abf5bb9d2dc1b879ab08d8aeb4d7ecb`;
the new source-ledger hash is
`e9baefd1532e70605e69cee1edd64a439562bf1a15c1dcde705b6318a7cdc22b`.
This is a complete **local API 31 ARM64 regression checkpoint**, not independent
x86_64 CI or proof that the earlier fresh-Gboard readiness failure cannot recur.

## Remaining gates

Resolve fresh-emulator keyboard readiness and the intermittent ViewState
insertion failure. Keep the original untraced
Unicode failure visible until its causal uncertainty is closed. Equal-width HStack distribution,
remaining Tier A/accessibility coverage, independent x86_64 CI, generated and
AgentC integration/release gates and a physical phone remain open. This probe
does not lower the minimum API, broaden a support claim or narrow the goal.
