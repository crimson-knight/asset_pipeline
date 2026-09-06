# Android Sheet viewport and allowed-height checkpoint — September 5, 2026

Status: full native, AgentC build and fresh CLI-consumer checks pass.
The full Android goal remains active. This is not full Tier A,
physical-device or public-release proof.

This is the earlier portrait-only checkpoint. The subsequent
[cramped-window follow-up](android-sheet-window-matrix-proof-2026-09-05.md)
records the adaptive landscape, enlarged-text/RTL and keyboard work and its
own current regression status. The artifact hashes below identify this earlier
implementation, not that follow-up.

## Changes and measured defects

The native scrolling viewport now follows the visible sheet height rather than
the larger native frame extending below the screen. One/two-height declarations
use Material's content-fit endpoints, keeping the maximum at the largest
declared logical height. Three-height declarations retain collapsed, half and
expanded positions. Keyboard exclusion raises compact sheets within the window
without changing their logical detent. See the [contract](android-sheets.md).

Three distinct defects were retained as failing evidence before correction:

1. The original medium sheet measured a 2,148-pixel viewport while only 1,074
   pixels were visible. The first corrected single-height reachability test
   passed, but did not yet measure the bottom exclusion independently.
2. Stronger geometry checks found the viewport ending at pixel 2,274 instead of
   2,337. Material's outer container had top/bottom padding of 63 pixels, shrinking
   its child to 2,274 pixels; our content then reserved the bottom inset again.
   Clearing padding only after `show()` did not hold. The actual attachment
   override now normalizes the two Material containers after the library's hook,
   and the canonical theme disables automatic surface inset padding/margins.
3. Small-only keyboard recreation failed because the sheet captured zero focused
   editors. Increasing bottom padding before its compact shell grew could measure
   the scrolling area at zero height and lose focus. The adapter now resizes the
   shell and frame together and does not replace that pending geometry with stale
   pre-layout bounds. Both the small-only and existing expanded composition/
   recreation tests then passed.

The adapter retains native Material shape, colors, controls, drag handling and
accessibility delegates. It does not clear application content padding, disable
scrolling, reset the runtime, extend test timeouts or ignore failed results.
The library behavior is documented in the pinned primary
[attachment source](https://github.com/material-components/material-components-android/blob/1.12.0/lib/java/com/google/android/material/bottomsheet/BottomSheetDialog.java)
and [surface styles](https://github.com/material-components/material-components-android/blob/1.12.0/lib/java/com/google/android/material/bottomsheet/res/values/styles.xml).

## Environment and focused evidence

Evidence root: `/tmp/ap-sheet-detents-proof.NdwMoL` (`/private/tmp` is the same
macOS directory). These temporary logs are not release artifacts.

- Task emulator: `emulator-5556`, ARM64 API 35, CheckJNI enabled.
- The existing `emulator-5554` is preserved. `devices.txt` contains only those
  emulators; no physical phone is visible. The task emulator has no reverse
  port mapping from this work.
- Crystal 1.21.0 / LLVM 22.1.8, NDK 28.2.13676358, native API 31,
  compile/target API 35, Gradle 9.3.1, Kotlin 2.2.21, Material 1.12.0.
- `baseline-instrumentation.txt`: the original viewport-height failure.
- `geometry-instrumentation-v1.txt`: one passing single-height reachability
  test (30.782 seconds), before the stronger independent exclusion assertions.
- `geometry-instrumentation-v2.txt` through `v4.txt`: bottom-exclusion failures;
  v3/v4 include measured container dimensions/padding. v4 proves that merely
  clearing padding after `show()` was not sufficient.
- `geometry-instrumentation-v5.txt`: actual gestures and all nine initial-height
  cases pass; small-only keyboard recreation fails (three tests, one failure).
- `geometry-instrumentation-v6.txt`: small-only focus capture fails with zero
  focused entries, while the existing expanded editor test passes.
- `geometry-instrumentation-v7.txt`: both editor tests pass, 48.975 seconds.
  The small sheet preserves its logical detent, actual editor focus, Unicode
  text/selection, visible keyboard, full editor visibility and bottom-action
  reachability through recreation and refresh.
- `geometry-instrumentation-v8.txt`: the new Back check exposed a test race.
  The logical label already said small, so the helper returned before its
  queued refresh actually replaced the window. Back then overlapped that
  replacement. The helper now requires the previous frame to detach before
  accepting the refreshed label; no production Back override was added.
- `geometry-instrumentation-v9.txt`: the corrected small-only test passes,
  25.885 seconds. The usable viewport stays at 411 pixels with the keyboard
  hidden, shown, restored, and hidden by Back. Native frame height changes
  from 600 to 1,420 pixels while the keyboard is open, then returns to 600;
  its logical selected detent remains small. Bottom edges meet the actual
  navigation/IME exclusions (2,337/1,517 pixels in this configuration).
- `shared-ui-spec.txt`: 1,450 examples, zero failures/errors, 66 existing pending
  checks. The new shared fixture check validates all seven nonempty detent sets.
- `cli-spec.txt`: the complete CLI host suite passes 525 examples, zero
  failures/errors/pending. This is broader than the prior generator-only lane.

## Integration validation

The mandatory positive lane passes **43 Android tests** (610.976 seconds) and
**91 JVM contracts** through `scripts/run_android_smoke.sh`, including all seven
Sheet tests from both native classes. The shared structure, Unicode scalar,
checked-JNI and native-file backend gates also pass. The package and source
checks succeed, followed by a normal CheckJNI relaunch. All **506** recorded
native source entries still match (`native-source-verification.txt`).

`screenshots-detents-final` contains small/medium/large-only and restored
small-keyboard captures from this passing run. The restored keyboard and
medium-only images were visually inspected, as was the expanded dark image in
`sheet-dark-final.png`. These complement the native geometry/action assertions;
they do not establish a broader font/device matrix.

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `59979eb0ddff4791616bb1c078f74a0401b1b7630a4a8d3669c2d464f75f1b6a` |
| Test APK | `ae911d269a25262df0891b3a5739120b79daf848f470d4fff9df3b5f2d88d52b` |
| Release App Bundle | `3bd8dc5ca78e74d32d04103d16e73306ce6b8c180f4b5285bb4b952b1f5a3007` |
| Native source ledger | `3cd23c5899f68460c2c2d62c96fbed99af04db02c7d5bd6bf981e74ddb717a7f` |

The complete `scripts/test_android_java_failures.sh` driver also passes all six
isolated Crystal failure cases (600 partial renders), the existing 100 malformed
semantics probes, 400 Java partial-render failures and the separate Sheet window
failure. The Java and Sheet lanes take 12.163 and 8.692 seconds respectively.
Original Throwable identity, terminal cleanup and a fresh normal CheckJNI
relaunch are verified. No unexpected runtime/CheckJNI failures or private test
sentinels escape into the checked logs.

### Fresh actual-CLI hybrid consumer

The current CLI was rebuilt as `<evidence>/amber`, SHA-256
`6bf13dd072ae23c3fa6dee11fc79ae910423889a9027f6535ee87d05a1e45218`.
`amber_cli/scripts/test_generated_android.sh` creates a fresh project at
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.LOqJnh`.
Explicit local development dependencies are disclosed; this is not public
release resolution or a manually repaired generated application.

- Two shared examples and actual web state/validation, CSRF and escaping checks
  pass. The complete generated Android package build succeeds (126 tasks,
  35 seconds), including both ABIs, debug/release APKs, test APK, App Bundle and
  matching native debug symbols.
- All **91 JVM contracts** pass, including seven Sheet policy tests. Both APK
  resource tables contain the new canonical Sheet theme/styles.
- **13 Android tests** pass in 35.839 seconds; the separate new-process
  restoration test passes in 5.243 seconds.
- Process 12886 saves count **26**; process 13018 verifies restoration with
  the exact name `Android 雪 😀 é`. The final normal process is 13068 and
  shows count 26, the same Unicode name and restored-local-storage status.
- All **730** source inputs remain byte-identical across the run: 36 generated
  app inputs, 242 Amber inputs and 452 AssetPipeline inputs.

The temporary web listener on port 3191 has exited, and the task emulator has
no reverse mappings. No app-data reset, account server or account database was
used. The generated counter proves runtime/package integration, not its own
Sheet UI; real Sheet interaction belongs to the canonical fixture above.

### Actual AgentC native target

`agentc-current/project` is an isolated development projection of the attached
AgentC account application with current local Amber/AssetPipeline dependencies.
`agentc-build.txt` passes all **91 JVM tests** and produces debug/release APKs,
test APK and release App Bundle for both ABIs (126 tasks, 1 minute 23 seconds).
`agentc-inspect.txt` verifies packaged ELF/JNI exports and matching native debug
symbols. Both APK resource tables include the new canonical Sheet theme/styles.

`agentc-source-verification.txt` confirms all **41** selected application inputs
remain unchanged in the original and projection. No installed libraries, live
accounts, database, server or original lock file was changed. This is build
regression for the real account target, not another account-interaction test or
a claim that its account screens contain a Sheet. Debug-only symbol-file
readelf warnings about absent dynamic tables are not packaged-library failures.

## Remaining full-goal work

This fixture is a portrait API 35 ARM64 phone-sized emulator proof. Cramped
landscape windows, larger text/RTL, tablets, nested popup controls, TalkBack and
accessibility focus, other APIs and actual physical devices remain separate
promotion gates. Arbitrary numeric detents, modal stacking and Apple material
effects are not supported by this bounded contract. Other Tier A renderer, CI,
public-release and released-consumer requirements remain open in the full plan.
