# Android test entrypoint and CI declaration — September 6, 2026

For the subsequent native regression, input-test corrections and first API 31
consumer proof, see the [later checkpoint](android-input-api31-proof-2026-09-06.md).
The unsuccessful runs below remain historical evidence, not the latest result.

Status: local entrypoint/configuration, callback ownership and full macOS/Linux
host suites pass. Three focused device checks and a fresh generated consumer
also pass. The earlier complete device run has three failures, including an
unexplained Unicode edit; no fully green current native/failure checkpoint,
remote CI run or public release is claimed. The full Android goal remains active.

Evidence root: `/tmp/ap-android-ci-proof.pJV04d`. These retained temporary logs
are local development evidence, not uploaded release artifacts.

## Defect and implementation

`placeholder-baseline.txt` records the former `make test-android`: it printed
the historical blocked message and returned zero without building or testing.
The old Android workflow job also ignored failures. Neither was runtime proof.

The new fixed wrapper requires an explicit serial, preserves serial/evidence
values as data and invokes the complete native/Crystal/Java/Sheet failure
driver. It rejects all nonempty `ANDROID_SMOKE_*` overrides, preventing inherited
partial-fixture settings from silently narrowing the public target. The old
ignored workflow job is removed; the separate pinned API 31/35 Linux workflow
is documented in [the runbook](android-ci.md). Other Apple/web jobs and unrelated
dirty source remain untouched.

## Local entrypoint and configuration checks

- `entrypoint-contract-v3/result.txt`: all 20 routing checks pass on macOS.
  They cover missing/malformed targets, exact quoted paths, literal Make
  expressions, command-line/environment values, fresh default evidence,
  inherited partial-smoke rejection and failure-status propagation. The copied
  fixture uses a test double; it is not Android runtime evidence.
- `missing-serial-real.txt`: the actual target exits 2 before starting a driver.
  `disconnected-serial-real.txt`: a serial first confirmed absent from the ADB
  inventory reaches the real driver and immediately fails; Make exits 2.
  Neither negative probe starts a build or modifies an emulator.
- `ci-specs-final.txt`: seven configuration specs pass. The initial
  `ci-specs.txt` records a YAML parsing error because unquoted `on` becomes a
  boolean key in the local parser; explicitly quoting the workflow key fixes
  interoperability without changing GitHub trigger semantics.
- `actionlint-final.txt`: actionlint 1.7.12 exits zero with no diagnostics.
  Its official macOS ARM64 archive was checksum-verified before execution.
- `macos-host-final.txt`: 1,457 examples, zero failures/errors, 66 existing
  pending checks. This comprises the seven CI declaration checks plus 1,450
  shared UI examples, not a native Apple platform test run.
- `ci-source-sha256.txt` identifies the seven entrypoint/workflow/spec inputs
  separately from the native driver's source ledger. This matters because the
  latter does not include the root Makefile, workflow YAML or CI spec.

## Linux host portability check

The Linux check uses the already available official Crystal 1.21.0 AMD64 image,
resolved to digest
`sha256:32b7b908a8c3625ebd629053daf48b6f469deaf74aeb71ad101895096b1665fa`.
It reports Crystal 1.21.0, LLVM 20.1.8 and target
`x86_64-unknown-linux-gnu`. Docker runs this AMD64 image through emulation on
the same Apple-Silicon computer; this is not an independent hardware/CI runner.
The container has no network, dropped capabilities, no-new-privileges, a
read-only root/source mount and a dedicated writable evidence/cache directory.

Preserved unsuccessful attempts:

1. `linux-host.txt` builds the shared test program but cannot execute it because
   the temporary filesystem was mounted without execute permission.
2. `linux-host-v2.txt` runs the suite and reports eight errors creating compile
   fixtures under the read-only repository's `tmp/compile-check`. The existing
   shared compile-check helper deliberately uses repository-relative fixtures
   for Crystal require resolution. This is not demonstrated production breakage.
3. The revised container grants executable temporary storage and mounts only
   `/source/tmp` as an additional writable temporary filesystem, keeping actual
   source read-only. `linux-host-v3.txt` completes 1,457 examples in 1:58 minutes
   (test execution, excluding compilation/linking): one failure, no errors,
   66 existing pending. Its GC/SwiftKit callback assertion exposes the concrete
   registry ownership defect below. This attempt is not a passing Linux check.

No tests were removed, made pending or softened to address these container
restrictions. The initial macOS routing check also exposed `/tmp` versus
`/private/tmp` normalization in the harness's expected path; canonicalizing its
owned evidence root with `pwd -P` fixed that test expectation.

## Shared callback ownership defect exposed by Linux

The original `.clear` removed callbacks **and reset the next token to 1**.
Meanwhile an outstanding `NativeView` can retain an old token until its later
finalizer unregisters it. Reusing that token lets stale ownership remove a new
callback; stale dispatch can also activate the wrong callback. This explains a
concrete way for the Linux GC assertion to observe `fired=0` despite registration.
The deterministic regressions establish the defect independently of the exact
GC timing in that earlier run.

`callback-clear-baseline.txt` reproduces three failures on macOS: stale action
dispatch invokes the new callback, stale cleanup removes a callback of another
type, and explicitly exercising an older NativeView's finalizer removes the
new action. The fixture uses an unowned fake native handle, never dereferenced;
the finalizer/registry operations are the real shared implementation.

Clearing registrations now preserves the process-wide monotonically increasing
token counter. All typed hashes still empty normally. The legacy counter-reset
spec is replaced with an explicit process-unique-ID contract; the new regressions
strengthen stale-dispatch, cross-type cleanup and finalizer ownership coverage.
No production reset hook, GC suppression, forced collection retry, ignored
failure or new pending test was introduced. Existing Android callback exception
boundaries and unrelated changes in the dirty registry file are preserved.

- `callback-clear-final.txt`: all 88 focused registry/NativeView/SwiftKit checks
  pass, including the three measured regressions.
- `macos-host-callback-final.txt`: all 1,460 host examples complete with no
  failures/errors and 66 existing pending, including 1,453 shared UI examples.
- `linux-host-v4.txt`: full Linux host suite after the fix passes all 1,460
  examples, no failures/errors, 66 existing pending; execution takes 1:54
  minutes, excluding compilation/linking. All 20 routing checks also pass.
- `ci-and-ownership-source-sha256.txt` and its verification include all ten
  selected CI/ownership implementation and spec inputs, including the new
  deterministic regression file.

## Complete native entrypoint proof

The actual Makefile target runs on the task-owned `emulator-5556`, ARM64
API 35. The other connected emulator, `emulator-5554`, remains untouched. The
inventory in `devices.txt` contains no physical phone.

`make-native-final.txt` is the **pre-callback-fix** outer target log;
`native-final/crystal-failures/positive/` contains fresh build/native evidence.
The package build succeeds in 38 seconds: 123 tasks, 14 executed and
109 up-to-date. Both native ABI libraries are rebuilt. JVM test execution is
up-to-date because its source is unchanged; the driver revalidates and retains
its nonempty passing reports. This is not a claim that 93 JVM tests reran in
this particular invocation. All 48 Android tests pass in 773.038 seconds.
`native-source-verification.txt` verifies 512 inputs before the callback fix;
it must not be represented as a verification of the subsequently changed
registry. The fixed source requires its own new build and complete device/
failure run. The original build's successful device result is retained as a
baseline, not substituted for that post-fix gate.

The pre-fix complete driver also passes the six isolated Crystal failure cases,
400 Java partial-render failures, original Throwable identity, Sheet window
failure and normal CheckJNI relaunch. Java/Sheet failure checks take
16.699/8.441 seconds. Its final outer Make status is zero.

`make-native-callback-final.txt` and `native-callback-final/` are the subsequent
build/run with the registry fix. Its text-contract assertion at source line 116
finds the rendered Crystal-owned value changed from `Before\0After…` to
`Before\0éter…` after submit. The direct composition/edit sequence had already
asserted the expected value synchronously. The exact input-method sequence
remains under investigation; the registry fix is not established as its cause.
The failure is not dismissed because an earlier 48-test run passed.

That run finishes in 712.105 seconds with 48 tests and **three failures**: the
Unicode assertion, the Sheet drag test observing state 2 instead of expanded
state 3, and the nine-height Sheet/Alert sequence missing its next editor.
Make exits 2 and the driver stops before the isolated failure lanes. This is
direct evidence that the new entrypoint rejects an actual failed device suite;
the unsuccessful run is not a completed native/failure checkpoint.

A bounded failure-only trace has been added to `AndroidTextContractTest` to
record the synthetic fixture's edits, selection/composing ranges and relevant
InputConnection call origin. This adds no application telemetry, changes no
assertion and does not suppress or replace the software keyboard. That source
change requires a rebuilt test APK before its trace can be evaluated.

The diagnostic hypothesis is concurrent input ownership: the fixture directly
creates/drives an InputConnection while the real keyboard is also attached.
Android documents [invalidateInput](https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#invalidateInput(android.view.View))
(API 33+) for cancelling stale IME requests after non-IME edits, and
[restartInput](https://developer.android.com/reference/android/view/inputmethod/InputMethodManager#restartInput(android.view.View))
for restarting input after changes outside the normal input flow. By contrast,
[finishComposingText](https://developer.android.com/reference/android/view/inputmethod/InputConnection#finishComposingText())
finishes the editor's current composition; it is not documented as cancelling
all pending remote requests. These references guide investigation, not proof of
this failure's origin or permission to weaken its exact-text assertion.

`unicode-trace-build.txt` rebuilds and installs the diagnostic test APK (28
seconds, 52 tasks). `unicode-trace-v1.txt` passes the focused test in 10.991
seconds. `unicode-trace-v2.txt` includes the four preceding native smoke tests,
then passes all five tests in 54.103 seconds. Neither reproduces the failing
edit, so the failure-only trace is absent. These passing repetitions are not
evidence that the Unicode defect has been fixed.

Two observation sequences in the Sheet tests are strengthened: the drag test
waits up to five seconds for the actual expanded Material state after its one
real swipe; the viewport loop waits for the follow-up Alert's app-root
replacement, restored window focus and zero native dialogs before starting the
next fixture. It no longer races the scheduled root retirement. The tests do
not repeat input, force a detent, disable animation, relax expected state, extend
their existing five-second readiness budget or alter production behavior.
`focused-three-source-sha256.txt` identifies the three current diagnostic/test
inputs. Their combined focused build/runtime result is recorded separately from
the failed full run and is not a substitute for complete regression proof.

`focused-three-build.txt` succeeds in 28 seconds. The subsequent
`focused-three-instrumentation.txt` passes all three selected tests in 88.788
seconds: Unicode editing, actual Sheet expansion/save and all nine Sheet/Alert
height cases. It reports normal instrumentation completion and no failure/skip
statuses. The source hashes still match afterward. The Unicode failure remains
unexplained despite this third passing diagnostic repetition. The complete
native/failure driver must be rerun after that investigation; focused success
does not erase the 48-test failing baseline.

## Consumer/package checks with the ownership fix

- `cli-spec.txt`: complete CLI host suite, 525 examples, no failures/errors or
  pending checks. `cli-build.txt` completes a fresh actual CLI executable at
  `<evidence>/amber`, SHA-256
  `b4ac60153d7ddd4fcb773bc810ee4ee2eeeca5f781101609cdbb232f421ae77c`.
  The fresh generated-consumer result below uses this executable.
- `agentc-build.txt`: the existing isolated AgentC source projection builds
  against the current canonical AssetPipeline/Amber development checkouts.
  It succeeds in 47 seconds, 126 tasks (17 executed, 109 up-to-date), including
  both native ABIs, debug/release APKs, test APK and App Bundle. JVM reports
  are reused for unchanged Kotlin source, not claimed as newly executed tests.
- `agentc-inspect.txt`: selected packaged ABIs, required ELF/JNI exports,
  permissions, test-secret exclusion and matching native debug symbols pass.
  The debug-symbol files' missing dynamic-table warnings are not packaged
  shared-library errors.
- `agentc-original-source-verification.txt` and
  `agentc-projection-source-verification.txt` verify all 41 application inputs
  against the earlier projection manifest. No original source, installed shard,
  account, database or account service is modified. No AgentC account runtime
  interaction is claimed for this package-only rerun.

### Fresh actual-CLI consumer

`generated-consumer.txt` records a new hybrid app at
`/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.w4je9M`.
The explicit development dependencies resolve to the current Amber and
AssetPipeline checkouts; this is not public released-shard resolution.

- Two shared examples and real web state, validation, CSRF rejection and HTML
  escaping checks pass.
- The fresh 126-task Android build executes every task and succeeds in 34
  seconds. All 93 JVM tests execute and pass: 15 reports, zero failures, errors
  or skipped tests. Both ABIs, APK variants, test APK, App Bundle and matching
  native symbols are verified.
- All 13 Android tests pass in 29.335 seconds. A separate process-restoration
  test passes in 4.742 seconds. Process 20928 persists count **30** and the exact
  Unicode name; process 21058 verifies restoration. Final normal process
  **21108** remains alive with count 30 and `Android 雪 😀 é` restored.
- The relaunch screenshot was visually reviewed: the native counter, name
  editor, Increment/Save name/Open details controls and restored-storage status
  are visible. This app does not exercise the sample's NUL/composition or Sheet
  fixtures and does not close their wider native regression gate.
- All **733** application/dependency source entries are unchanged before/after:
  36 generated, 242 Amber and 455 AssetPipeline inputs. The separate current
  native ledger verifies 512 inputs, including the diagnostic/Sheet test
  changes; it identifies source, not a passing full-run result for those inputs.

Final checks: only the two existing emulators are visible to ADB, no physical
phone; the dedicated emulator's orientation is restored (`user_rotation=0`)
and reverse mappings are empty. The task's port-3191 web listener and isolated
Linux test container have exited. The other emulator was not operated.

## Remaining full-goal gates

The new workflow has not been committed, pushed, dispatched or observed on
GitHub. No branch protection, remote repository setting, credential, published
artifact or installed release was changed. Local declaration checks and a
same-machine Linux host suite do not establish Linux NDK builds, KVM/emulator
provisioning, API 31/35 runtime behavior or remote artifact retention.

Actual independent CI, Amber/CLI/AgentC integration CI, remaining Tier A and
window/device/accessibility coverage, physical ARM64 phone proof and public
released-consumer verification remain open in
[the full implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).
