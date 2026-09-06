# Android 16 / API 36 native checkpoint — September 6, 2026

Development proof for the migrated toolchain (compile/target SDK 36, Build Tools
36.0.0, AGP 8.13.2, Gradle 9.3.1, Kotlin 2.2.21, NDK 28.2.13676358, native and
minimum API 31). Evidence root: `build/android-local-proof/` in the
`android-target` worktree; the durable copy of earlier session evidence is
`~/android_target_evidence/2026-09-04_to_06/`. The full Android target goal
remains active; this checkpoint closes the API 36 migration and the Android 16
behavior audit, not the device, release or Tier A gates.

## Devices

| Serial | API | ABI | Page size | Role |
| --- | --- | --- | --- | --- |
| emulator-5560 | 36 | arm64-v8a | 16384 | target-36 proof (AVD `ap_android36_16k_20260906`) |
| emulator-5556 | 35 | arm64-v8a | 4096 | regression |
| emulator-5558 | 31 | arm64-v8a | 4096 | minimum-version regression (earlier checkpoint) |
| GitHub `ubuntu-24.04` | 31, 35, 36 | x86_64 | 4096 | first remote and first x86_64 execution |

`emulator-5554` has a stalled ADB transport and is not used.

## What changed for API 36

1. `CompoundButton.OnCheckedChangeListener` and `RadioGroup.OnCheckedChangeListener`
   are declared with non-null parameters in the SDK 36 stubs. The runtime's two
   nullable overrides were the only compile failures of the migration.
2. Keyboard restoration after a sheet dialog window is recreated. Android 15
   re-showed a saved-visible keyboard itself (`SHOW_RESTORE_IME_VISIBILITY`);
   Android 16 does not, rejects a direct client request issued as the new window
   gains focus (`PHASE_SERVER_UPDATE_CLIENT_VISIBILITY`), and cancels the system's
   own in-flight show when the client requests at that moment
   (`PHASE_CLIENT_APPLY_ANIMATION`). The sheet now declares
   `SOFT_INPUT_STATE_ALWAYS_VISIBLE` before its window attaches when the saved
   state had a keyboard, requests the IME through the insets controller right
   after `dialog.show()`, and at focus only confirms after 900 ms. A stuck request
   (client types already include the IME, server never showed) is cleared with
   hide-then-show, never while an IME animation is in flight, up to four times.
   See [the sheet contract](android-sheets.md).
3. Everything else in the target-36 behavior list was audited and needs no
   change; see [the readiness audit](android-36-readiness.md).

## Test-protocol defects found by the migration

- The injected-Tab traversal assertion raced the platform: with an input method
  attached, traversal finishes on a later main-loop turn. The test waits for the
  focus move. This was the previously unexplained intermittent Tab failure, and
  it reproduced on API 35 as well.
- Sheet tests matched inside the dialog root before a slower emulator had
  attached it, and tapped Save while the expanded sheet still laid out. Both now
  wait for the root and for a stable rectangle.
- The window-matrix landscape test held an editor reference across a keyboard
  restoration that can complete a deferred full-tree refresh. It re-resolves the
  sheet parts before checking.

## Results

Local, complete `make test-android` driver (build both ABIs, debug and test
APKs, release bundle, 50 instrumentation tests, all isolated Crystal, Java and
Sheet failure lanes, source ledger verification):

| Target | Result | Evidence |
| --- | --- | --- |
| emulator-5560, API 36, 16 KB pages | exit 0, `OK (50 tests)` | `build/android-local-proof/api36-run3` |
| emulator-5556, API 35 | exit 0, `OK (50 tests)` | `build/android-local-proof/api35-run2` |

Focused loops on the classes that changed, run sequentially with no competing
load: window-matrix and sheet-contract classes three of three on API 35 and two
of two on API 36; semantics class plus the drag test four of four on API 36 and
three of three on API 35.

Remote (GitHub `ubuntu-24.04`, x86_64 emulators, `android-native.yml`): every
API level builds both ABIs, the debug APK and the release bundle from source and
executes the instrumentation suite. Run four reached 49 of 50 on API 31 and
API 36; run five reached 46 of 50 on API 31 while API 35 ran for the first time
and lost 33 tests to one environmental cause, an app window that never received
focus on a two-core software-rendered emulator. Run six adds the runner's four
cores, keyguard dismissal and on-failure screen and focus capture; its result
is recorded in `docs/android-ci.md` when it settles.

The 16 KB proof is the same complete driver on the `google_apis_ps16k` image
(`getconf PAGESIZE` 16384), not the earlier frozen target-35 probe.

## Explicit limits

- Local results are arm64 emulators on one Mac plus GitHub's x86_64 runners.
  The physical phone has not been attached to ADB.
- The toggle-retry path is exercised by the API 36 emulator under full-suite
  load; it is not a claim about every input method.
- No public release, Tier A promotion or generated-consumer release proof is
  made here.
