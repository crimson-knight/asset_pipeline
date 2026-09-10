# Android callback and render failure contract

Status: development implementation, not full JNI safety certification. The full
[Android target plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md) remains open.

## Checked UI entrypoints

The canonical Kotlin host uses five checked Crystal exports:
`crystal_android_host_callback_void`, `_string`, `_bool`, `_float`, and `_int`.
Each returns `1` after successful dispatch, including a stale-ID no-op, or `0`
after a contained Crystal exception. The string form accepts a pointer and byte
length, preserving standard UTF-8 and embedded NUL. Negative lengths and a null
pointer with a positive length fail without reading the buffer.

The JNI callback methods return `jboolean`; the matching private Kotlin methods
return `Boolean`. Hosts must consume the matching canonical C and Kotlin sources.
Do not combine an old unchecked native library with the new Kotlin runtime.
Generated artifact inspection requires the five checked exports in both ABIs.
Legacy C callback symbols retain their old signatures; on Android their errors
are contained and logged, but their void ABI cannot communicate failure status.
They are not substitutes for the checked host entrypoints.

Callback diagnostics contain the callback kind and exception class, not the
exception message or input. The diagnostic path is itself guarded. This policy
also now applies to the shared render/lifecycle/service exception logger, which
reports only the exception class with a guarded fixed fallback. Bootstrap and
Android platform diagnostics remain separate paths.

## Terminal session behavior

`HostSession.nativeCall` allows UI calls only in a usable foreground session.
An exception raised inside that call changes the session to `FAILED` and is
re-thrown on the Kotlin side. A checked callback failure prevents the normal
post-callback refresh. A failed render or navigation call also makes the session
terminal. Precondition rejection before entering the native call does not itself
manufacture a failed session.

After failure, subsequent callbacks, renders and activation are rejected. Back
queries/commits return false. The owning Activity may still stop and detach,
release views and callbacks, and explicitly close services. No failed-session
reset or same-process retry API is provided. A fresh Android process is the
recovery boundary; this does not roll back application mutations made before an
exception or undo persisted writes.

This is containment, not an automatic error screen. An unhandled Kotlin
exception in a normal Android event handler can still terminate the app. Hosts
that present a failure screen must stop calling the failed session, complete
normal cleanup and define their own restart experience.

## Partial render ownership

The Android renderer retains every `NativeView` created during a render,
including unattached containers and leaves whose callbacks already exist. On
success, ownership transfers to the returned native tree. On a Crystal render
exception, all created views are explicitly torn down in reverse construction
order, then renderer stacks and the partial result are cleared before rethrow.
Idempotent `NativeView.teardown!` releases children, callback registrations and
global JNI references. Cleanup does not depend on running a garbage collection.

The application currently tears down its previous native tree before rendering
the replacement. A failed replacement is not a transactional restoration of the
previous screen.

## Verification commands

Run the ordinary clean lane with `scripts/run_android_smoke.sh`. Its host checks
include `android_callback_boundary_spec.cr` plus the callback registry suite;
its runtime diagnostics reject checked-callback failures as well as crashes.

Run the deliberate-failure lane separately:

```sh
bash scripts/test_android_failure_boundaries.sh <adb-serial> <evidence-directory>
```

The script first rebuilds/packages and runs the clean regression. It then runs
the sample's `AndroidFailureBoundaryTest` once per `failure_kind` argument, in
six separate instrumentation processes: void, string, bool, float, int, render.
Do not put this terminal-session test into a shared-process positive suite or
run it without its required argument.

Each case first fails 100 partial native renders and requires immediate exact
reference/callback baseline restoration. It then triggers one terminal error,
checks rejected reuse, tears down the owning Activity, and requires zero native
references, callbacks and pending services. The script requires the exact
expected diagnostic, runtime initialization and CheckJNI evidence; it rejects
crashes, skipped tests and private callback text. Finally it starts a separate
ordinary process and checks that the native screen mounts cleanly.

## Explicit remaining safety work

- The [checked JNI layer](android-jni-errors.md) now covers View/collection
  operations, typed optional lookup errors and repeated genuine Java render
  failures. Continue auditing direct platform-service paths, allocation/cleanup
  failures and bootstrap diagnostics; this is not universal native safety.
- Audit asynchronous service-completion failure policy separately. Completions
  and terminal cancellation may legitimately arrive while no UI is foreground;
  they must not blindly reuse the foreground-only UI gate.
- Prove cleanup failures, low-memory conditions, broader render primitives,
  full ABI/API matrices and physical devices. No native signal, process death,
  arbitrary bad pointer or out-of-memory recovery guarantee is made here.

Android requires native code to stop or handle pending Java exceptions before
making most further JNI calls; managed exceptions do not unwind native frames.
This is a separate obligation from catching Crystal application exceptions.
See the official [JNI exception guidance](https://developer.android.com/ndk/guides/jni-tips#exceptions).

The shared callback registry also now preserves an explicit `false` result from
a string-policy callback; only a missing callback defaults to `true`. The old
`result || true` expression accidentally overrode a real denial. Host regression
tests cover this correction; Apple runtime behavior was not exercised by this
Android proof.
