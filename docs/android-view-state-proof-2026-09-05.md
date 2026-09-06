# Native view-state checkpoint — September 5, 2026

Status: **verified native and fresh generated-consumer development progress**.
This is development progress, not completion of the full Android compile target.
The [view-state contract](android-view-state.md) defines supported behavior and
the conservative full-tree replacement policy.

## Implementation

The canonical host now preserves keyed editor focus/selection, native one-/two-
axis scroll offsets and a bounded screen history across refresh, recreation and
Back. Asynchronous refresh waits for active composition to finish. Explicit
actions may replace immediately. Text/domain state stays in Crystal.

Metadata identity is independent of accessibility/test strings. Explicit screen
keys survive reconstruction; unkeyed navigation screens use non-recycled
Crystal allocation tokens and a Kotlin process nonce. Duplicate addresses are
discarded, and unkeyed positions require an unchanged semantic tree shape.
Native wrappers and internal Material children remain transparent to that shape.

Framework subtree saving is disabled for Crystal-owned views. Saved metadata
does not contain entered text, native references or callbacks. Password
selection is omitted. Typed malformed Bundle fields are rejected without
logging their values. Actual serialized state, including current/history Bundle
overhead, is capped at 192 KiB; tree/entry/address bounds remain independent.
Over-budget traversal produces a fixed warning and an observable ordinary
refresh fallback rather than crashing the application.

The Android CLI template now mounts through the same host, includes canonical
runtime resources, saves state through Activity lifecycle callbacks, assigns
stable counter/page/editor keys, checks the new JNI export in both ABIs and
requires the shared matching-policy unit report. Its application test asserts
editor state after recreation and both native Back paths.

## Native proof

Final evidence: `/tmp/amber-android-view-state-proof/native-streamed`.

- Clean lane: **70 JVM tests, 23 Android tests in 142.858 seconds**, five shared
  view-state/identity examples, four layout structure examples and existing
  callback/navigation/asset/C prerequisites.
- New native tests exercise real composition across the refresh deadline,
  replacement after commit, cursor range, exact two-axis offsets, sibling
  insertion, stopped-window capture/return, recreation, isolated second-screen
  state and Back restoration. Explicitly hidden/disabled fields stay excluded.
- Actual Parcel bytes exclude synthetic editor text in UTF-8 and UTF-16LE.
  A positive control enables Android hierarchy saving and detects the same
  editor text before the test verifies the disabled subtree excludes it.
- Malformed types, unknown/invalid fields, an oversized incoming Bundle,
  sensitive selection omission and dense current/history serialization pass.
- A deliberately oversized native metadata tree exercises the real host's
  fixed warning, skipped-state counter, successful refresh and zero native
  references/callbacks after teardown.
- **600 Crystal partial-render failures** pass in six isolated processes
  (26662, 26725, 26783, 26847, 26905, 26963).
- **400 Java partial-render failures** pass in process 27082, in 7.708 seconds;
  original exceptions and explicit cleanup are preserved. The subsequent normal
  application mounts in process 27142 with CheckJNI and the embedded-runtime
  probe, without native failure diagnostics.

All device results above are the isolated API 35 ARM64 emulator, serial
`emulator-5556`. Both ARM64 and x86_64 libraries/package entries build; x86_64
runtime and physical-phone validation are not implied.

Native package identities from the clean lane:

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `0d0549a172c29d65fcf1793ae292f473613d24c9b18de401fb56bc61079415ae` |
| Test APK | `7086cafefbdcfda8ff7ad05536646e9c20708865a401e5685b1b2a1309c99a16` |
| Release App Bundle | `033325d1bc1efdff56bcd2bef977bbda2a43ef8d456ffb57464099bfbfbc0a2f` |
| Source ledger | `759e59be2dc845d3db0691d6b13087adf81c22d80d7e0f923e0f0709dc55597b` |

The ledger records dirty and untracked source, not just the repository commit.
Every recorded source checksum still matches before final consumer generation.

Additional shared regression: **432 Crystal examples** for shared views, state,
environment, fluid layout, adapters, accessibility metadata and the new fixture.
CLI regression: **159 examples**. Logs are retained under
`/tmp/amber-android-view-state-proof/shared-ui-spec.txt` and `cli-spec.txt`.

## Final fresh generated consumer

Evidence:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.hFpPFA`.

The actual rebuilt CLI is `/tmp/amber-android-view-state-proof/amber`, SHA-256
`3dcf4217413f10b09270da6665a8e0dea521dc6ac199c73272a555f51ac1f987`.
Its new app resolves the explicit local-development Amber/AssetPipeline shards;
this is not the released-consumer lane.

- Two shared examples and real web state/validation/CSRF/escaping checks pass.
- **70 JVM tests, 13 Android tests in 26.202 seconds**, and a separate read-only
  process-restoration test in **3.578 seconds** pass.
- The generated native editor retains focus and its exact selection through
  background/return, recreation, toolbar Up and system Back. No test or generated
  app source was repaired after generation.
- All **712 source entries remain unchanged**: 36 generated, 242 Amber and
  434 AssetPipeline entries, including untracked runtime files.
- Process 27299 persists count **14** and the exact name `Android 雪 😀 é`
  (the final accent is decomposed). Process 27432 verifies the native Unicode
  value without saving or incrementing. The final ordinary cold launch is
  process **27482**.
- Both ABI packages, required JNI exports, compiled image resources, explicit
  permissions and matching native debug symbols pass inspection.

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `80e93bc6853a18561fa9cd4e442cc167416d69667fde87b651e140e248dd0671` |
| Unsigned release APK | `8d3f0753fe7c3865b018f02c546ea986f8d615c0ea6563c388a4736a5a910333` |
| Release App Bundle | `7af4a0ca3512eeaa2850cba164dea81d92074f794020afb5f7fbc90598deedb2` |

The final `android-runtime/relaunch.png` was visually inspected: native toolbar,
bundled image, counter, bounded name field, buttons and restoration message are
visible without overlap. A final device query confirms
`com.example.counter.app/dev.amber.generated.MainActivity` is the resumed Activity
on emulator-5556, with PID 27482. Only emulators 5554/5556 are visible to ADB;
the physical phone remains unavailable. The existing visible emulator was not
modified by this proof, which used the isolated headless emulator.

## Earlier attempts retained

The evidence root also retains the initial recursive Kotlin refresh-runnable
compile failure and its typed-runnable fix. The first broad runtime attempt
exposed two old test assumptions that refresh always jumps to the top: one
display assertion now deliberately scrolls to its label; the submit test waits
for the actual native label value without relying on viewport visibility.

The initial composition fixture ended its input batch before waiting, allowing
the real IME to finish composition before the deferred branch ran. It now holds
the batch until that branch has been observed. Its next attempt exposed the
Android 31+ outermost `endBatchEdit()` false return contract, corrected using the
platform implementation/API documentation. The subsequent `state-third` run
passes 14 focused Android tests. `state-hardened` passes all 23 tests before the
final serialized-size gate; `native-verified` is the earlier complete native run
before the generated consumer revealed the stopped-window gap.

The first fresh consumer, `amber-generated-android.45sQB4`, passes its shared/web
checks but fails Crystal cross-compilation because the generated navigation
class variable's keyed `.tap` initializer needs an explicit type annotation.
The generator source and regression assertion were corrected; that generated
directory was not repaired in place. The final consumer was regenerated using
the rebuilt CLI, as recorded above.

The next fresh consumer, `amber-generated-android.GHKCXF`, builds both native
ABIs and all packages, but its added focus assertion fails after a stopped/
resumed Activity is recreated. `stopped-state-reproduction` reproduces the
specific failure in the canonical sample: the stopped editor still has native
focus, but its snapshot entry is absent because capture used full-window
`isShown()`. Capture now checks visibility only within its mounted subtree;
explicitly hidden/disabled application fields remain excluded. The canonical
test now asserts the real hidden-window case and resumes/recreates before Back.
The final complete native and fresh-consumer proofs above include this fix.

`native-final` passes all **23 behavioral tests in 151.779 seconds**, including
the new stopped-window assertions, but fails the required startup-log evidence
gate. Its main log buffer starts at 15:13:45 while instrumentation began at
15:12:56; unrelated emulator logging displaced the startup records. The runner
now resolves the exact installed app UID and captures its logs continuously,
supplemented by a final buffer tail. The capture is stopped on success or exit,
and an unexpectedly stopped capture is a failure. Gates are unchanged; no global
log-buffer clearing or resizing is needed. The final complete native proof uses
`native-streamed` rather than treating the earlier missing evidence as a pass.

## Remaining gates

This milestone is not in-place reconciliation, full focus/accessibility parity,
automatic domain/route restoration, a public release or an AgentC migration.
State keys must not contain user-entered or secret data. API 31/x86_64 runtime,
tablet/device screenshots, physical-phone proof, remaining Tier A controls and
modifiers, generated metadata regeneration, AgentC's three shared-use-case
screens, CI, signing/release artifacts and released-consumer proof remain open.
The [full plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md) remains active.
