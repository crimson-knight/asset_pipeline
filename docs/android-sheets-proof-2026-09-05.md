# Android native Sheet checkpoint — September 5, 2026

Status: canonical runtime, AgentC build regression and fresh generated-app
proof pass. The full Android goal remains active. This is local development proof,
not Tier A promotion, a public release or a physical-device result.

The subsequent [viewport/allowed-height checkpoint](android-sheet-detents-proof-2026-09-05.md)
corrects shorter-sheet sizing, inset attachment ordering and small-only editor
focus, with additional real gesture and keyboard tests. The hashes/results
below identify this earlier initial-window milestone, not the later build.

## Implementation

`UI::Sheet` now mounts Crystal-owned content in a real Material bottom-sheet
window instead of an inline card. The [bounded contract](android-sheets.md)
describes the supported behavior and remaining promotion work.

The implementation includes native detents/drag handles, explicit and structural
dismissal, SheetPresenter closure, locked cancellation, separate keyed window
metadata, keyboard/composition-aware replacement, retired-control event leases,
and checked post-layout/window failure handling. Removing or replacing a Sheet
declaration finishes its dismissal once; matching refreshes and lifecycle
teardown remain silent. A dismissal may sequence a subsequent native alert.

Keyboard avoidance is owned once by the sheet. Visual inspection and a measured
viewport assertion exposed a duplicate IME gap that the initial editor tests did
not catch. Explicit inset handling with no second WindowManager resize corrects
the expanded editor layout. See the pinned Material
[attachment implementation](https://github.com/material-components/material-components-android/blob/1.12.0/lib/java/com/google/android/material/bottomsheet/BottomSheetDialog.java)
for the outer container/decor behavior normalized by the adapter.

## Evidence location and environment

Evidence root: `/tmp/ap-native-sheet-proof.vtmASj` (the macOS `/private/tmp`
alias identifies the same directory). These temporary logs are not checked-in
release artifacts.

- Task emulator: `emulator-5556`, ARM64 API 35, CheckJNI enabled.
- The existing `emulator-5554` was preserved. A fresh ADB inventory still found
  no physical Android phone.
- Crystal 1.21.0 / LLVM 22.1.8, NDK 28.2.13676358, native API 31,
  compile/target API 35, Gradle 9.3.1, Kotlin 2.2.21, Material 1.12.0.
- Both ARM64 and x86_64 native libraries build. x86_64 execution and other
  Android API/device configurations were not tested by this checkpoint.

## Confirmed focused results

- `sheet-instrumentation-v9.txt`: **4 tests pass**, 184.534 seconds. They cover
  real separate windows; large/medium detents; light/dark presentation; Done,
  SheetPresenter, Back, outside and locked programmatic dismissal; retired
  button/editor suppression; actual IME composition; Unicode text, selection,
  focus and keyboard through recreation; background/resume; structural removal
  and changed identity; sheet-to-alert sequencing; real upward drag and saving
  from within the sheet.
- `keyboard-instrumentation-v8.txt`: expanded keyboard viewport and recreation
  pass. `screenshots-v8/sheet-keyboard.png` was visually inspected after the
  inset correction; it shows the actual Unicode editor and native keyboard.
- `failure-instrumentation-v11.txt`: isolated window-mutation failure passes,
  preserving the original Throwable, retiring the live sheet and preventing old
  controls from dispatching before final root cleanup. This focused test injects
  a failure through the post-render window-mutation boundary; it is not exhaustive
  fault injection at every Android window operation.
- `shared-ui-spec.txt`: **1,449 examples**, zero failures/errors, 66 existing
  pending probes. This is the shared host suite, not an Apple native run.
- `shared-v9.txt`: seven Sheet contracts plus three Alert contracts pass.
- `cli-spec-final.txt`: **181 examples**, zero failures/errors/pending.

## Final integration gates

The complete canonical proof passes through
`scripts/test_android_java_failures.sh emulator-5556 <evidence>/native-final`.
Its positive lane passes **40 Android tests** in 516.669 seconds, all **87 JVM
contracts**, shared
serialization/fixture checks, actual package/source ledgers and a normal
CheckJNI relaunch. Separate processes pass all six Crystal failure cases (600
partial renders), the existing 100 malformed-semantics cases, 400 Java partial
renders, and the new Sheet window-failure lane. Java failure proof takes 13.263
seconds; Sheet failure proof takes 8.381 seconds. A fresh normal process is
mounted after the terminal failure processes. Logs contain no unexpected
runtime/CheckJNI failure or private test sentinel.

`native-source-verification.txt` confirms all **504** recorded native inputs
still match the built source ledger. These include untracked development files;
the repository commit alone is not the identity of this dirty-tree build.

| Artifact | SHA-256 |
| --- | --- |
| Debug APK | `55d5bb6b54a0b5d11a05110b8804351cef247c7f4643dc9a1ec48bde26d516fc` |
| Test APK | `070d9210c39ba4e472e351a916707065645058e02898a03af13eedd849d878c4` |
| Release App Bundle | `148acfca571d358672d664188f977fdfddb690a516e067a6081dabb868a99f05` |
| Native source ledger | `a268c6e94410d58d2be86ec716a2a4adebdaf2e6e08ac9950de5d7cfb31bcb79` |

`screenshots-final` contains the passing run's light/dark, Unicode keyboard and
drag/save captures. These are separate-window UI proof, not the historical
inline-card visual matrix.

The rebuilt actual CLI is `<evidence>/amber`, SHA-256
`afa0b35dead3da803ef0aefad2e310c29dc479dc381923de1d7c35dc92cee5e4`.
The stricter generated/attached test scripts require `SheetPolicyTest` and
both native sheet exports plus the structural-transition entrypoints.

### Fresh actual-CLI hybrid consumer

Evidence: `/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.zi6lpV`.
The actual CLI creates this application in a new directory. Explicit local
development dependency overrides are disclosed, not represented as public
release resolution. No generated application source edits were needed.

- Two shared examples and real localhost web state/validation checks pass.
- **87 JVM contracts** and **13 Android tests** pass (38.684 seconds), followed
  by one separate exact-state restoration test (5.491 seconds).
- Process 9236 saves count **24**; process 9369 verifies restored state with the
  exact Unicode name `Android 雪 😀 é`. The final normal launch leaves the
  generated app installed and running as process 9419.
- Debug/release APKs and release App Bundle contain both ABIs and matching
  native debug symbols, with the newly required Sheet exports present.
- All **729** recorded inputs remain byte-identical across the run: 36 generated
  app inputs, 242 Amber inputs and 451 AssetPipeline inputs. The canonical Sheet
  unit report and artifact export gates are present in the actual generated
  scripts, not only in generator-class assertions.

The temporary web server exits after the checks. The proof neither clears
application data nor creates device forwarding for this local web test.
The generated counter exercises runtime compatibility and restoration, not its
own Sheet UI; Sheet interaction proof belongs to the canonical fixture above.

## Real AgentC native target

`agentc-current/project` is a task-local projection of the actual attached
AgentC account application, with explicit current Amber/AssetPipeline native
dependencies. `agentc-source-verification.txt` verifies all **41** selected app
inputs remain byte-identical in the original and projection.

`agentc-build.txt` passes **87 JVM tests** and builds debug/release APKs, the
test APK and release App Bundle for both ABIs (126 tasks, 1 minute 54 seconds).
`agentc-inspect.txt` verifies packaged ELF/JNI exports and matching native debug
symbols. The inspector's debug-only ELF files have no dynamic table; its
readelf warnings are not failed export checks on packaged libraries.

This is current-runtime build regression for the real account target. It does
not repeat sign-in/API interaction proof or claim that the account screens
contain a Sheet. No installed project libraries, live account data, server,
database or existing dependency lock were modified for this projection.

## Development failures retained in the evidence

Early fixture builds failed on incorrect Crystal call syntax; these were fixed
before runtime testing. One successful build omitted the newly added test class
from its packaged tests; the nonempty runner check caught ClassNotFound rather
than accepting ADB's zero exit status. Later proof builds use a fresh Gradle
process with file-system watching disabled; the precise omission cause was not
conclusively established.

The initial composition probe used a standalone BaseInputConnection instead of
the actual editor connection; it was replaced with a real IME connection and
explicit composing-span assertions. A locked Back test also incorrectly treated
the injection helper's return value as the dismissal outcome; it now injects
Back and checks that the locked window remains present.

The duplicate keyboard-space assertion failed in v6/v7 and passes after the v8
inset ownership correction. A privacy-test build attempted a protected Activity
method directly; it now uses Android's instrumentation lifecycle API. Its next
run passed the saved-state checks but hit an Espresso idle timeout while keeping
an IME batch deliberately open. The final test checks the exact attached,
focused, active-lease composing editor and deferred-refresh counter on the main
looper, then finishes the batch before requiring normal Espresso idleness.
No longer timeout, ignored failure, runtime reset or production workaround was
introduced to turn these failures green.

## Remaining full-goal work

At this initial-window checkpoint, remaining work included detent-specific viewport/scroll reachability,
small-only keyboard usability, downward and locked swipe behavior, nested popup
controls, large text/RTL/landscape, TalkBack and the phone/tablet/API matrix.
Custom numeric detents, arbitrary modal stacking and Apple material effects are
not claimed. Existing platform, full core Tier A, CI, physical-device and public
released-consumer gates remain open in the
[full implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).
