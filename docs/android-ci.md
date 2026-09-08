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
instrumentation session on the same device during this target. The driver
also sets two device settings for the duration of the run and restores them
on exit: `block_untrusted_touches` to permissive and `spell_checker_enabled`
to `0`; the run notes below record why each exists.

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
  layout, editor/view state, semantics/focus, dialogs/sheets, the host tick, the
  host viewport and platform storage, secrets and files. It verifies completed nonempty instrumentation plus clean
  app-scoped diagnostics, not just ADB's process exit code.
- Separate processes exercise intentional Crystal callback/render failures,
  Java partial-render failures, original Throwable preservation, Sheet window
  failure and terminal cleanup. Expected failure diagnostics are kept out of the
  clean lane. A fresh normal CheckJNI process must mount afterward.
- Evidence includes source hashes (including relevant untracked source),
  package hashes, toolchain/device details, instrumentation, JVM reports, logs
  and relaunch captures. A separate system-tag log, the image's autofill,
  spell-check and screen-timeout settings and, on failure, dispatcher and
  power state plus the tests' own screenshots are kept for diagnosis only;
  no gate reads them. Temporary local paths are not published artifacts.

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


## Physical device, September 7

`make test-android` passed on a Samsung Galaxy A15 5G (SM-A156U, Android 16,
One UI 8, arm64-v8a, 1080 by 2340 at 450 dpi, three-button navigation,
Samsung Keyboard with Samsung's spell checker, no SIM and no Wi-Fi): 64 device
tests OK and both isolated failure lanes PASS, driver exit 0, on the sixth
run of the day. The first run passed 59 of 64 and named six differences from
the x86_64 and arm64 emulators; five were test assumptions and one was a
renderer defect.

| Difference the phone exposed | Where | Resolution |
| --- | --- | --- |
| The host page's own header leaves a fixture's echo labels below the fold on the shorter display; UiAutomator text waits only see what is on screen | structure, navigation tests | the waits scroll the text into view (Espresso `scrollTo`) while waiting |
| The host's deferred post-recreation refresh lands after a faster phone hands Espresso the view it then replaces | smoke test | bounded retry around the post-recreation scroll and display check |
| Espresso's `scrollTo` returns early once 90% of a view is visible, and the phone's shorter small detent left the editor 4 px clipped there | sheet viewport test | request the whole editor rectangle before requiring all of it |
| One UI hands a nested vertical viewport's drag to the parent scroller; stock Android gives it to the child. A real swipe inside the two-axis viewport scrolled the host page on the phone and the inner content on the emulator | renderer | vertical viewports are the runtime's `CrystalScrollView`, which keeps the vertical drags it can consume and yields at an edge (`ScrollGesturePolicy`, JVM-tested) |
| A fast swipe's fling is still animating when the next tap arrives, and a ScrollView intercepts that touch-down to stop the fling, swallowing the tap | layout test | wait for both viewports to come to rest before positioning and tapping |
| Two page taps inside the host's 250 ms refresh debounce: an open tap landed before a reset tap's refresh, one render carried both, and the sheet never presented; the follow-up render the host should have produced did not come | sheet viewport test; runtime | the test settles after each page tap; the runtime race stays open (see below) |

The driver's device controls behave the same on the phone: it set
`block_untrusted_touches` permissive and `spell_checker_enabled` to `0` for
the run and restored both to their prior values (`null`). Runs two through
five each removed findings and added one of their own (a hand-closed app
during a run, and a settle wait that read the mount through Espresso's root
picking while a sheet window held focus). Evidence for the passing run and
the first-contact run lives outside the repository with the other proof
directories.

**Open runtime finding.** The lost sheet presentation is a race between two
quick taps and the host's debounced refresh, reproduced three times on the
phone and never on an emulator: after the coalesced render, the host should
render again and present, and no second render was logged within five
seconds. The mechanism of the missing render is not yet instrumented; it is
not the scroll-view change (the same test passed and failed with and without
it, on the same side of the same timing). Treat a fast reset-then-open pair as
unsupported until it is named.

The phone's clock was stale (no network time), which does not affect these
tests but fails any TLS proof against a certificate issued this week; the
template lane reissues its task-only certificate with a validity window that
covers the device's date.

Before these changes went to CI, the six test classes they touch ran together
on the local API 35 emulator: 29 tests, one failure, the text contract's
post-close check that every JNI global reference is released (44 remained,
166 ms after the activity was destroyed). The class alone then passed all 13
tests on the same emulator, as it had on the phone, on the API 31 emulator and
on CI run 22, so this is the teardown-sequencing family from the September 6
notes and not a change in the runtime; the CI matrix is the arbiter. CI run 23 (34142227181), the first run carrying these changes, passed 64 tests on each of API 31, 35 and 36.
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
| 13 | activity-tap stability, dialog-root diagnostics | 53/56 (two dropped taps, one dropped injected tap) | 54/56 (keyboard visible and active, sheet window without focus) | **pass** |
| 14 | bounded tap retries | 53/56 (first tap after three fresh launches refused by the input dispatcher) | 54/56 (a focusable popup owned by the app process held window focus in landscape) | **pass** |
| 15 | system-log diagnostics | 55/56 (untrusted-touch drop: the test package's EmptyActivity still covered the app) | 54/56 (a focusable app-owned popup attached to the sheet held window focus) | **pass** |
| 16 | structure suite (59 tests), permissive untrusted touches, autofill off | **pass** | 57/59 (same popup with autofill off, so autofill was not its cause) | **pass** |
| 17 | pickers suite (61 tests), autofill control withdrawn, popup content diagnostic | **pass** | 59/61 (the popup is Android's text-suggestions window, opened by the spell checker's flag on the previous test's draft) | **pass** |
| 18 | list suite (62 tests), pushed before the spell-checker control | **pass** | 60/62 (same suggestions popup, same two landscape tests) | **pass** |
| 19 | tabs suite (64 tests), spell checker disabled for the run | **pass** | **pass** (first green API 35 job; no focus diagnostics) | **pass** |
| 20 | docs-only push after run 19 (same code) | **pass** | **pass** | 63/64: the landscape-keyboard test asserted the drag handle on the first keyboard-hidden frame (test timing; see below) |
| 21 | sheet-matrix wait (same 64 tests) | 63/64: the Unicode composition test tapped the multiline editor before the deferred post-recreation refresh (test timing; see below) | **pass** | **pass** |
| 22 | text-contract settle wait (same 64 tests) | **pass** | **pass** | **pass** |
| 23 | physical-device fixes and `CrystalScrollView` (same 64 tests) | **pass** | **pass** | **pass** |
| 24 | hugging-stack measure pass and `root_fill` on Android, `layout-hugging` fixture (65 tests) | **pass** | **pass** | **pass** |
| 25 | host tick (`on_tick`, `TickPolicy`, `tick-contract` fixture; 67 tests) | **pass** | 66/67, then **pass** on rerun: the list-rows tap was delivered one row above its target (see below) | **pass** |
| 26 | docs-only push after run 25 (same code) | **pass** | 66/67: the same list-rows tap; the echo label did not show the row within the wait (see below) | **pass** |

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
Run 13 settled the API 35 x86_64 question as far as evidence allows: the sheet
did receive window focus this time, the keyboard opened and became active on
the focused editor, and the sheet window then reported no window focus while
the keyboard stayed visible and active. Opting the editor out of fullscreen
and extract mode did not change it. That is the `google_apis` API 35 x86_64
image's landscape keyboard behavior, not something the app controls, and API
35 arm64 passes the same tests locally, 56 of 56. API 35 x86_64 is recorded as
the lane's known limit: its two landscape sheet keyboard tests are expected to
fail there until the image changes. Every other x86_64 miss since run 9 was a
dropped input on the software emulator; taps and injected clicks now retry a
bounded number of times without relaxing any assertion.

Run 14 showed that bounded retries do not cover the API 31 x86_64 miss. Its
three failures share one shape: the first tap after a fresh activity launch,
one to four seconds after the activity resumed, and every one of the nine
injection attempts was refused by the input dispatcher within about 130
milliseconds, with no Espresso security retry and no timeout. That is a
dispatcher-level drop, whose reason is only written to the system log. The
API 35 x86_64 wait also produced a sharper clause: the opened sheet lost
window focus to a `PopupWindow`, while the activity stayed the focused
application. Neither the app-scoped log nor a screenshot can name that popup
or the drop reason, so the driver now captures a system-tag log
(`logcat-system.txt`: input dispatcher, input manager, window manager,
activity manager, power, input method and autofill services) beside the
app-scoped one, records the image's autofill, spell-check and screen-timeout
settings (`device-services.txt`), and on failure keeps `dumpsys input`,
the power state, the tests' own timeout screenshots (`sheet-proof/`) and
Espresso's view-operation captures (`espresso-output/`). The dialog-root wait
also names the focused window's owner, type and flags and lists every window
root the app process holds. No gate reads any of these files.

Run 15 named both. The API 31 x86_64 system log reads, for every refused
injection: `Untrusted touch due to occlusion by dev.assetpipeline.androidhost.test
(obscuring opacity = 1.00, maximum allowed = 0.80)`, then `Dropping untrusted
touch event`. The obscuring window belongs to the **test package**, which has
its own UID: `ActivityScenario` closes a scenario by starting androidx
test-core's `EmptyActivity` over the app, and on a slow emulator with
animations enabled that opaque window is still on screen when the next test
has already launched and resumed its activity. Android 12's tapjacking
protection then drops every touch to the app until the harness window is
gone, which is why the first tap after a fresh launch failed nine times in a
row and no retry could help. That is a property of the harness, not of the
app or a user: the driver now sets `block_untrusted_touches` to permissive
(logged, not dropped) for the run and restores the previous value afterward.

The API 35 x86_64 focused-window record from run 15 narrowed the popup:
owned by the app's UID, a `PopupDecorView` of type
`APPLICATION_ABOVE_SUB_PANEL`, focusable, attached to the `Native editor sheet`
window, transparent format, as wide as the focused editor, holding a
`PopupBackgroundView`. Run 15's system log showed the autofill service
creating a pending intent at the same moments, so run 16 ran with
`autofill_service` set to `null`; the popup appeared anyway with no autofill
session at all, so autofill is not its cause and that setting is not applied.
Run 16 is the first green API 31 job since run 9; the API 31 cause above is
settled.

Run 17 named the popup. The dialog-root wait's content classes read
`PopupBackgroundView[RelativeLayout[LinearLayout]]`, which is the framework's
`text_edit_suggestion_container_material` layout (a `RelativeLayout` holding
the `suggestionWindowContainer`), and the tests' own timeout screenshots show
it: Android's text-editor suggestions window (`Editor.SuggestionsPopupWindow`)
open over the sheet editor, the draft's last token highlighted, and Gboard's
suggestions listed. The chain: the sheet fixture keeps its draft in a module
variable, so a landscape test opens the sheet with the previous test's draft,
which ends in `e` plus a combining acute accent. The image's spell checker
(Gboard's `AndroidSpellCheckerService`, the same package on all three images)
flags that token with an easy-correction `SuggestionSpan`. The test's
centering tap on the wide landscape editor lands past the end of the short
text, so the cursor goes to the text end, on that span's boundary. Android
15's `Editor.onTouchUpEvent` then posts `replace()` after the double-tap
timeout, which opens the focusable suggestions popup and takes window focus
from the sheet. Whether the spell-check result lands before or after that
tap is timing, which is why only the x86_64 API 35 runner showed it and the
local arm64 API 35 image never did. A third-party dictionary's verdict on a
fixture token must not decide a run, so the driver now sets
`spell_checker_enabled` to `0` for the run and restores it on exit, beside
the untrusted-touch control; `device-services.txt` still records the image's
spell checker as found. The runtime is unchanged: a user who taps a flagged
word gets the same system popup, and the sheet regains focus when it closes.

Run 20 was the docs-only push after run 19 and failed one test of 64, on
API 36 only: the sheet matrix's landscape-keyboard test, at the assertion
that the drag handle is shown again after Back hides the keyboard. The
runtime restores the handle in the sheet's own inset pass (the inset
animation's end callback), which runs after the root insets already report
the keyboard hidden; the test waited for the second and asserted the first
on the same frame, and the software-rendered API 36 emulator was between the
two. The test now waits for the handle and the fitted viewport with the same
ten-second bound as its other waits. The runtime is unchanged.

Run 21 carried the sheet-matrix wait and failed one test of 64 on API 31
only, a third timing case of the same shape: the text contract's Unicode
composition test recreates the activity and then taps the multiline editor.
The host defers a whole-tree refresh by 250 ms after recreation; on the
software-rendered API 31 emulator the tap landed before that refresh, focused
the editor the refresh then replaced, and the replacement had no focus. The
test now waits until the tree has reported the same editor instance for
longer than the deferral before tapping. The runtime is unchanged. All three
runner findings are in the tests, not the renderer: a test that asserts a
frame the runtime updates one pass later fails only on a slow emulator.

Run 25 carried the [host tick](android-host-tick.md), a one-second
main-looper callback that now fires in every fixture, and failed one test of
67 on API 35 only: the structure contract's list-rows test tapped "Banana"
and the echo label reported the row above it ("Row: 0; section: 0,0; taps:
1"), so the tap was delivered one row above the coordinates Espresso
computed. The callback and the refresh render both happened on time. The
tick did not run between the coordinate computation and the injection (its
first tick posts behind the first render and later ticks are a second
apart), and no tick-driven render appears in the window. Run 24 shows the
identical sequence for this test, including the same compositor stall before
the tap, and passed. The rerun of the API 35 job passed, and four scoped
passes of the structure suite on the local API 35 emulator with the tick
active passed. The cause is not named; it is recorded as an input-timing
observation on the x86_64 runner, and the runtime is unchanged.

Run 26 (34162524157), the docs-only push after run 25, failed the same test
on API 35 again, 66 of 67: after the tap on "Banana" the echo label did not
show "Row: 1; section: 0,1; taps: 1" within the wait. That is two consecutive
API 35 runs on the list-rows tap since the tick landed, after run 24 passed
the identical sequence, so it is now a pattern to watch rather than noise.
The bridge's checked callback only calls into Crystal and checks the result;
it never notifies the refresh observer, so a tick schedules no refresh, and
no tick-driven render appears in either run's log. The test that runs
immediately before it is the sheet window matrix, which rotates the display
to landscape and restores it; whether the display was still settling when
the structure host laid out is the next thing to check if a third run shows
the shape. The runtime is unchanged.
