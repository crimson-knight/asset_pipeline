# Android native validation

`make test-android` runs the real AssetPipeline Android build, device tests and
isolated failure checks. It is no longer a message-only placeholder. The target
requires one explicitly named ADB device and returns failure for absent devices,
build errors, empty/failed instrumentation or unexpected runtime diagnostics.

This is the canonical AssetPipeline fixture gate, not a claim that every native
view, generated application, device, CI runner or public release is supported.
The full scope remains in
[the implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).

## Run locally

Install the toolchain declared by `config/android_toolchain.env`, including its
Crystal version, JDK major, SDK platform/build tools and NDK revision. Set
`ANDROID_SDK_ROOT` and `JAVA_HOME` to those installations. On Linux, install the
native build prerequisites listed in `.github/workflows/android-native.yml`.
The shared resolver accepts either `ANDROID_SDK_ROOT` or `ANDROID_HOME`; explicit
configuration takes precedence over its macOS defaults.

Build both native dependency bundles once, in a dedicated cache:

```bash
export CRYSTAL_CACHE_DIR="$PWD/build/crystal-cache/android"
export CRYSTAL_CROSS_DEPS="$PWD/build/android-deps"
bash scripts/doctor_android.sh
source scripts/android_env.sh
while IFS= read -r abi; do
  BUILD_DIR="$CRYSTAL_CROSS_DEPS" bash scripts/build_android_deps.sh "$abi"
done < <(android_each_abi)
```

The doctor without a selected device checks compile/package prerequisites; its
no-device warning is **not** a device-test pass. Inspect the available ADB
devices, then select a dedicated emulator or an explicitly authorized test phone:

```bash
export ANDROID_SERIAL=emulator-5556
export ANDROID_TEST_EVIDENCE="$PWD/build/android-local-proof"
make test-android
```

The serial above is an example, not auto-selection. A missing, malformed,
disconnected, unauthorized or offline target fails. The wrapper rejects all
nonempty `ANDROID_SMOKE_*` settings, including partial test classes or alternate
fixtures; specialized probes must call their scoped helper explicitly. Serial
and evidence values are passed as data, including spaces in evidence paths,
without evaluating embedded Make or shell expressions. Direct wrapper failures
preserve the driver's exit status; GNU Make reports recipe failures as nonzero.

If `ANDROID_TEST_EVIDENCE` is absent, the wrapper creates a fresh temporary
directory and prints it. Relative evidence paths resolve from Make's working
directory. Prefer a fresh directory for each proof; retained output is not
automatically cleaned. If `CRYSTAL_CACHE_DIR` is absent, the wrapper selects
`build/crystal-cache/android` under this checkout.

The driver installs/replaces the canonical sample and its test package on the
selected target, enables CheckJNI there, performs UI/lifecycle tests and leaves a
normal sample process running. Do not use a personal device or an emulator with
important sample-app data without accepting that test activity. It does not
reset the entire device, select another connected device, or declare success
because no device is available. Do not run UI automation or a second
instrumentation session on the same device during this target.

## What the target proves

`scripts/test_android_target.sh` delegates to
`scripts/test_android_java_failures.sh`, which includes the positive smoke and
Crystal failure driver before separate Java and Sheet failure processes.

- Host contracts cover the native file backend, Unicode codec, JNI guards,
  asset compiler and selected shared state/view contracts.
- Fresh native builds produce both ABI libraries, debug APK, instrumentation
  APK and release App Bundle. The build checks native architecture/link inputs;
  the smoke checks packaged ABI entries, debug symbols, permission policy and
  nonempty JVM reports.
- The mandatory native class list tests real controls, callbacks, navigation,
  layout, editor/view state, semantics/focus, dialogs/sheets and platform storage,
  secrets and files. It verifies completed nonempty instrumentation plus clean
  app-scoped diagnostics, not just ADB's process exit code.
- Separate processes exercise intentional Crystal callback/render failures,
  Java partial-render failures, original Throwable preservation, Sheet window
  failure and terminal cleanup. Expected failure diagnostics are kept out of the
  clean lane. A fresh normal CheckJNI process must mount afterward.
- Evidence includes source hashes (including relevant untracked source),
  package hashes, toolchain/device details, instrumentation, JVM reports, logs
  and relaunch captures. Temporary local paths are not published artifacts.

Broader shared Crystal specs and entrypoint/configuration checks are separate
host gates in CI. The cheap routing test deliberately substitutes a driver in
an isolated copied fixture; it proves routing and failure propagation only,
not Android execution:

```bash
bash scripts/tests/android_target_entrypoint.sh
CRYSTAL_CACHE_DIR="$PWD/build/crystal-cache/android" \
  crystal spec spec/android_ci_spec.cr spec/web/ui --error-trace
```

## Declared GitHub Actions lane

`.github/workflows/android-native.yml` declares a fresh Ubuntu 24.04 job for
each runtime API in `[31, 35, 36]`, with an x86_64 Google APIs Pixel 6 emulator.
Each job builds **both** `arm64-v8a` and `x86_64` libraries using the canonical
native API pin (currently 31). Runtime API 35/36 does not silently raise the
native compilation floor. ARM64 packaging is not ARM64 runtime proof on these
x86_64 CI emulators.

The workflow:

1. Checks out source without persistent credentials, installs pinned Crystal
   and Java versions, installs the canonical SDK/NDK packages and runs the doctor.
2. Requires readable/writable KVM acceleration; it does not quietly substitute
   a software-only emulator or ignore an unavailable device.
3. Runs entrypoint and shared/configuration host contracts, then builds both
   ABI dependency bundles from the pinned recipes.
4. Runs the exact public `make test-android` target against its owned
   `emulator-5554`, with a software keyboard and animations enabled.
5. Rejects tracked source rewrites and retains evidence/APKs/App Bundles for
   14 days, including on failure. Missing all requested artifact paths is an
   artifact-step error, not a silent upload success.

All external actions use full commit IDs; dependencies/toolchain pins remain
centralized. Jobs have a 60-minute bound, do not use `continue-on-error`, and
run both matrix entries even if one fails. They trigger on relevant pull-request
changes, relevant pushes to `main`, or manual dispatch. Permissions are
`contents: read`; there is no release, publishing, signing-secret or deployment
step. Superseded runs of the same ref are cancelled. Repository branch
protection and required-check configuration are separate administrative gates.

The old ignored Android placeholder job has been removed from
`initiative-cross-platform-ui.yml`. Other Apple/web jobs are preserved, including
their existing limitations. `make test-all` still means web plus macOS; its
message explicitly points to the separate Android target.

Action behavior was checked against primary sources:
[Crystal installation action](https://crystal-lang.github.io/install-crystal/index.html),
[Java setup](https://github.com/actions/setup-java),
[Android SDK setup](https://github.com/android-actions/setup-android), and
[Android emulator runner](https://github.com/ReactiveCircus/android-emulator-runner).
The emulator runner's annotated v2 tag was resolved to its peeled commit before
pinning. Local workflow syntax validation uses
[actionlint 1.7.12](https://github.com/rhysd/actionlint/releases/tag/v1.7.12).

## Proof boundaries and remaining work

Configuration specs and workflow lint establish local declaration consistency;
they do not prove GitHub provisioning, KVM, either declared API runtime, SDK
downloads, Linux native cross-linking, emulator boot or artifact retention.
Likewise, an AMD64 Linux container on this Apple-Silicon computer is a useful
host portability check, **not** an independent CI machine or hardware runtime.

No workflow has been published or dispatched as part of authoring this lane.
Record actual remote run URLs, source/package manifests, both matrix outcomes,
artifacts and failure behavior before calling independent CI complete. Do not
weaken or skip native tests merely to obtain a green workflow.

The first remote runs may reveal API, keyboard, window or runner assumptions;
preserve those failures and fix the affected implementation or test contract.
Physical ARM64 phone proof, the remaining component/device/accessibility matrix,
generated-project release resolution, Amber/CLI/AgentC integration CI and public
release proof remain separate full-goal gates. See the implementation plan for
the acceptance criteria rather than treating this one fixture lane as parity.

## Linux runner notes (first real remote runs, September 6, 2026)

The declared workflow ran on GitHub's `ubuntu-24.04` runners with x86_64
emulators at API 31, 35 and 36. Three host-portability defects surfaced and are
fixed:

- The runner preinstalls NDK 27.3 and exports it as `ANDROID_NDK_HOME`. The
  resolver now walks `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT` and the SDK's pinned
  directory and takes the first whose `Pkg.Revision` matches the pin.
- The host's `gradle.properties` carried `org.gradle.java.home` pointing at one
  Mac's Android Studio JDK. It is removed; the driver exports `JAVA_HOME` from the
  toolchain resolver and CI sets it through `setup-java`.
- The raw-JNI structural gate searched with ripgrep inside `if`; without `rg` the
  command exited 127 and the violation branch never ran, so the gate reported PASS
  on any host lacking it, including this runner. It now scans with perl and
  self-tests.

One runner in the matrix reported no `/dev/kvm`; the workflow fails that job
loudly rather than skipping the device lane. Re-run the job on a fresh runner.
Both packaged ABIs, the debug APK and the release bundle build on Linux, and the
x86_64 libraries execute: API 31 and API 36 emulator jobs each completed all 50
instrumentation tests before the fixes above landed.

### Run results, September 6

| Run | Change under test | API 31 | API 35 | API 36 |
| --- | --- | --- | --- | --- |
| 1 | initial push | NDK pin mismatch | NDK pin mismatch | NDK pin mismatch |
| 2 | NDK resolver | 49/50 | no KVM on runner | 47/50 |
| 3 | JDK path removed | 46/50 | no KVM on runner | 50 tests, 3 keyboard misses |
| 4 | keyboard fix, test waits | 49/50 | KVM udev race | 49/50 |
| 5 | guarded retry, dialog-root wait, KVM retry | 46/50 | 17/50 (no window focus, 2-core emulator) | host spec crash (raw-thread mutex) |
| 6 | 4-core emulators, keyguard, diagnostics, lock-free identity | **pass** | 48/50 (two wait budgets) | **pass** |
| 7 | package history, ten-second sheet waits | 47/50 (taps dropped before the session was foreground) | 17/50 (launcher ANR dialog held focus) | **pass** |
| 8 | error dialogs suppressed, basics promotion | 47/50 | 48/50 (landscape keyboard readiness) | **pass** |
| 9 | foreground wait, stabilized taps, focus tap point | **pass** | 48/50 (landscape keyboard readiness) | **pass** |
| 10 | 56 tests (basics suite), stable-root readiness | 55/56 (viewport tap mid-layout) | 54/56 (landscape keyboard) | **pass** |
| 11 | keyboard settle, viewport taps, readiness diagnostics | 55/56 (dropped horizontal fling) | 54/56 (window focus lost while the keyboard was visible and active) | **pass** |
| 12 | staged keyboard retry, no extract UI, gesture retry | 55/56 (activity tap mid-layout) | 54/56 (opened sheet never gains window focus in landscape) | **pass** |

"pass" means the complete `make test-android` driver exited 0: both ABIs
built from source, debug APK and release bundle packaged, 50 instrumentation
tests, every isolated failure lane, and the tracked-source check. Run 6 is the
first fully green remote execution and the first x86_64 pass at API 36. The two
API 35 misses in run 6 were a five-second keyboard wait and a dialog-root wait
that let Espresso's focus timeout escape; both budgets are widened.

Run 7's diagnostics answered the API 35 question: the retained focus dump and
screenshot show the emulator booting into "Pixel Launcher isn't responding", a
SYSTEM_ALERT window that held focus before the app was installed. The driver
now sets `hide_error_dialogs`, closes system dialogs and backs out of an ANR
dialog before installing. Run 7's API 31 misses were taps issued after a
recreation before the host session was foreground again, which the host drops
by design; the sheet tests now wait for that state before tapping, and the
focus test waits for its editor to finish scrolling into view before it taps.

Run 9 is the first green API 31 job. The API 35 image's remaining pair is the
landscape keyboard readiness wait: the keyboard was shown within a second of
the tap, but the wait also required the dialog decor to equal the display
size, which never holds on an image whose landscape navigation bar sits
beside the window. The wait now requires a stable root size instead. From
run 10 the suite is 56 tests, including the basics contract suite.

Run 11's readiness diagnostics named the API 35 clause: the keyboard was
visible and active on a focused editor while the editor's window had no
window focus, which is what a fullscreen extract-mode keyboard does in
landscape. Sheet editors now also set `IME_FLAG_NO_EXTRACT_UI`. The local API
35 trace showed the keyboard-restore retry's hide landing after its own show;
the retry is now staged one action per interval. The remaining API 31 miss was
a dropped horizontal fling on the software emulator; the gesture test repeats
the real gesture up to three times before judging it.

Run 12 narrowed the API 35 x86_64 case further: both landscape sheet tests
now fail in the dialog-root wait itself, before any keyboard, because the
freshly opened sheet never receives window focus on that image in landscape.
The wait now records the focused window and a screenshot when it gives up.
Until that is understood, API 35 x86_64 is the one lane that does not pass
the complete driver; API 35 arm64 passes it locally, 56 of 56.
